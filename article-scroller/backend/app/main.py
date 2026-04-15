from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
import sqlite3
import os
import httpx
import xml.etree.ElementTree as ET
from app.database import toggle_article_save, save_articles
from datetime import datetime, timedelta
import urllib.parse
import httpx
from bs4 import BeautifulSoup
from markdownify import markdownify as md

DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'scroller.db')

app = FastAPI(title="Article Scroller API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

@app.get("/")
def read_root():
    return {"status": "API Online"}

@app.get("/api/feed")
def get_feed(limit: int = Query(5), offset: int = Query(0)):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute(
        "SELECT * FROM articles ORDER BY id DESC LIMIT ? OFFSET ?",
        (limit, offset)
    )
    articles = cursor.fetchall()
    conn.close()
    return [dict(article) for article in articles]

@app.post("/api/articles/{article_id}/toggle-save")
def toggle_save(article_id: int):
    new_status = toggle_article_save(article_id)
    return {"id": article_id, "is_saved": new_status}

@app.get("/api/saved")
def get_saved_articles():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM articles WHERE is_saved = 1 ORDER BY id DESC")
    articles = cursor.fetchall()
    conn.close()
    return [dict(article) for article in articles]

@app.get("/api/top")
async def get_top_articles(category: str = Query("Todas"), timeframe: str = Query("month"), q: str = Query("")):
    query_parts = []
    
    if q.strip():
        query_parts.append(f'all:"{q.strip()}"')

    cat_map = {
        "Inteligência Artificial": "cat:cs.AI",
        "Ciência da Computação": "(cat:cs.CC OR cat:cs.CR OR cat:cs.DC OR cat:cs.SE OR cat:cs.PL)",
        "Engenharia de Software": "cat:cs.SE",
        "Criptografia e Segurança": "cat:cs.CR",
        "Física Geral": "cat:physics.gen-ph",
        "Astrofísica": "cat:astro-ph",
        "Matemática": "cat:math.HO",
        "Economia": "cat:econ.GN",
        "Biologia Quantitativa": "cat:q-bio",
        "Neurociência": "cat:q-bio.NC",
        "Genética e Genômica": "cat:q-bio.GN",
        "Longevidade e Biologia Celular": "(cat:q-bio.CB OR cat:q-bio.MN)"
    }
    
    if category in cat_map:
        query_parts.append(cat_map[category])
    elif category == "Todas" and not q.strip():
        query_parts.append("cat:cs.AI")
        
    now = datetime.now()
    start_date = None
    
    if timeframe == 'week': start_date = now - timedelta(days=7)
    elif timeframe == 'month': start_date = now - timedelta(days=30)
    elif timeframe == 'year': start_date = now - timedelta(days=365)
    elif timeframe == '3years': start_date = now - timedelta(days=3*365)
    elif timeframe == '5years': start_date = now - timedelta(days=5*365)

    if start_date:
        start_str = start_date.strftime("%Y%m%d%H%M")
        end_str = now.strftime("%Y%m%d%H%M")
        query_parts.append(f"submittedDate:[{start_str} TO {end_str}]")

    search_query = " AND ".join(query_parts) if query_parts else "all:research"
    safe_query = urllib.parse.quote(search_query)
    
    url = f"https://export.arxiv.org/api/query?search_query={safe_query}&sortBy=relevance&sortOrder=descending&max_results=30"
    
    headers = {"User-Agent": "ArticleScrollerLive/5.0"}
    live_articles = []
    
    async with httpx.AsyncClient(follow_redirects=True, timeout=20.0) as client:
        try:
            response = await client.get(url, headers=headers)
            if response.status_code == 200:
                root = ET.fromstring(response.text)
                ns = {'atom': 'http://www.w3.org/2005/Atom'}
                
                for entry in root.findall('atom:entry', ns):
                    title_el = entry.find('atom:title', ns)
                    summary_el = entry.find('atom:summary', ns)
                    author_el = entry.find('atom:author/atom:name', ns)
                    link_el = entry.find('atom:id', ns)
                    published_el = entry.find('atom:published', ns)
                    
                    if title_el is not None and summary_el is not None:
                        live_articles.append({
                            "title": title_el.text.strip().replace('\n', ' '),
                            "author": author_el.text if author_el is not None else "Unknown",
                            "content": summary_el.text.strip().replace('\n', ' '),
                            "source": link_el.text if link_el is not None else "",
                            "category": category,
                            "published_date": published_el.text if published_el is not None else ""
                        })
        except Exception as e:
            print(f"Live fetch error: {type(e).__name__} - {str(e)}")

    conn = get_db_connection()
    cursor = conn.cursor()
    enriched_articles = []
    
    for article in live_articles:
        try:
            cursor.execute('''
                INSERT INTO articles (title, author, content, source, category, published_date)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (article['title'], article['author'], article['content'], 
                  article['source'], article['category'], article['published_date']))
            conn.commit()
        except sqlite3.IntegrityError:
            pass 
            
        cursor.execute("SELECT id, is_saved FROM articles WHERE source = ?", (article['source'],))
        db_data = cursor.fetchone()
        
        if db_data:
            article['id'] = db_data['id']
            article['is_saved'] = db_data['is_saved']
            enriched_articles.append(article) 
            
    conn.close()
    
    return enriched_articles

@app.get("/api/articles/full-text")
async def get_full_text(source_url: str):
    full_url = source_url.replace("arxiv.org", "ar5iv.org")
    
    headers = {"User-Agent": "ArticleScrollerBot/1.0"}
    
    try:
        async with httpx.AsyncClient(timeout=30.0, follow_redirects=True) as client:
            response = await client.get(full_url, headers=headers)
            
            if response.status_code == 200:
                soup = BeautifulSoup(response.text, 'html.parser')
                
                for tag in soup(["script", "style", "nav", "footer", "header"]):
                    tag.decompose()
                
                content_node = soup.find('article') or soup.find('main') or soup.find('body')
                
                if content_node:
                    # Convert HTML to clean Markdown
                    markdown_text = md(str(content_node), heading_style="ATX")
                    return {"content": markdown_text}
                
                return {"content": "Content structure not recognized."}
            else:
                return {"error": f"Ar5iv returned status {response.status_code}"}
    except Exception as e:
        print(f"Extraction error: {e}")
        return {"error": str(e)}