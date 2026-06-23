# utils/utils.py

def is_safe_sql(sql: str):
    banned = ["delete", "drop", "update", "insert", "alter"]
    return not any(word in sql.lower() for word in banned)