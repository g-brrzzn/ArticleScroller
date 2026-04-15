import asyncio
import httpx
import xml.etree.ElementTree as ET
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from app.database import init_db, save_articles

# Categorias que queremos minerar
CATEGORIES = ["cs.AI", "cs.LG", "physics.gen-ph", "math.HO"]

async def fetch_batch(client, category, start, max_results=100):
    """Busca um lote específico usando paginação (start)"""
    url = f"https://export.arxiv.org/api/query?search_query=cat:{category}&start={start}&max_results={max_results}&sortBy=submittedDate&sortOrder=descending"
    
    try:
        response = await client.get(url)
        if response.status_code != 200: return []
        
        root = ET.fromstring(response.text)
        ns = {'atom': 'http://www.w3.org/2005/Atom'}
        papers = []

        for entry in root.findall('atom:entry', ns):
            papers.append({
                "title": entry.find('atom:title', ns).text.strip().replace('\n', ' '),
                "author": entry.find('atom:author/atom:name', ns).text,
                "content": entry.find('atom:summary', ns).text.strip().replace('\n', ' '),
                "source": entry.find('atom:id', ns).text,
                "category": category,
                "published_date": entry.find('atom:published', ns).text
            })
        return papers
    except Exception as e:
        print(f"Erro no lote {start}: {e}")
        return []

async def deep_scan():
    init_db()
    async with httpx.AsyncClient(timeout=30.0) as client:
        for cat in CATEGORIES:
            print(f"\n🚀 Iniciando varredura profunda em: {cat}")
            # Vamos pegar os últimos 500 artigos de cada categoria em lotes de 100
            for offset in range(0, 500, 100):
                print(f"  -> Baixando lote {offset} a {offset+100}...")
                papers = await fetch_batch(client, cat, offset)
                if papers:
                    salvos = save_articles(papers)
                    print(f"  ✅ {salvos} novos artigos salvos.")
                
                # Respeitar a API do ArXiv (Crucial para não ser banido)
                await asyncio.sleep(3) 

if __name__ == "__main__":
    asyncio.run(deep_scan())