import psycopg2

# --- Conexión a base de datos de SEDES ---
def obtener_conexion():
    try:
        conexion = psycopg2.connect(
            host="localhost",
            user="postgres",
            password="root123",
            dbname="sedes_uneg",
            port="5432",
            client_encoding="UTF8"
        )
        return conexion
    except Exception as e:
        print("Error al conectar a la base de datos sedes_uneg:", e)
        return None


# --- Conexión a base de datos de CATEGORÍAS y FALLAS ---
def obtener_conexion_categorias():
    try:
        conexion = psycopg2.connect(
            host="localhost",
            user="postgres",
            password="root123",
            dbname="categorias_fallas",
            port="5432",
            client_encoding="UTF8"
        )
        return conexion
    except Exception as e:
        print("Error al conectar a la base de datos categorias_fallas:", e)
        return None


# --- Conexión a base de datos de REPORTES GENERALES ---
def obtener_conexion_reportes_generales():
    try:
        conexion = psycopg2.connect(
            host="localhost",
            user="postgres",
            password="root123",   #  en tu código anterior pusiste "troot123" (error tipográfico)
            dbname="reportes_generales",
            port="5432",
            client_encoding="UTF8"
        )
        return conexion
    except Exception as e:
        print("Error al conectar a la base de datos reportes_generales:", e)
        return None
