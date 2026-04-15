import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'scroller.db')

def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db_connection()
    conn.execute('''
        CREATE TABLE IF NOT EXISTS articles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT UNIQUE,
            author TEXT,
            content TEXT,
            source TEXT,
            category TEXT,          -- 🟢 NOVA COLUNA: Qual a área da ciência?
            published_date TEXT,    -- 🟢 NOVA COLUNA: Data (ex: 2026-04-10)
            is_saved INTEGER DEFAULT 0
        )
    ''')
    conn.commit()
    conn.close()
    print("🗄️ Banco de dados inicializado com sucesso (com Categorias e Datas).")

def save_articles(articles):
    conn = get_db_connection()
    cursor = conn.cursor()
    inserted_count = 0
    for article in articles:
        try:
            cursor.execute('''
                INSERT INTO articles (title, author, content, source, category, published_date)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (article['title'], article['author'], article['content'], 
                  article['source'], article['category'], article['published_date']))
            inserted_count += 1
        except sqlite3.IntegrityError:
            pass
    conn.commit()
    conn.close()
    return inserted_count

def toggle_article_save(article_id: int):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("UPDATE articles SET is_saved = CASE WHEN is_saved = 1 THEN 0 ELSE 1 END WHERE id = ?", (article_id,))
    conn.commit()
    cursor.execute("SELECT is_saved FROM articles WHERE id = ?", (article_id,))
    new_status = cursor.fetchone()[0]
    conn.close()
    return bool(new_status)