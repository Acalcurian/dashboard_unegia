from flask import Blueprint, render_template, jsonify, current_app
from conexion import (
    obtener_conexion,
    obtener_conexion_categorias,
    obtener_conexion_reportes_generales
)



dashboard_bp = Blueprint('dashboard', __name__)

@dashboard_bp.route("/dashboard")
def dashboard():
    try:
        # 1) Contar totales por categoría en reportes_generales
        conexion_r = obtener_conexion_reportes_generales()
        cur_r = conexion_r.cursor(dictionary=True)
        cur_r.execute("""
            SELECT categoria AS categoria_id, COUNT(*) AS total
            FROM reportes
            GROUP BY categoria
        """)
        totals_by_cat = cur_r.fetchall()
        cur_r.close()
        conexion_r.close()

        # 2) Obtener nombres de categorías desde categorias_fallas
        conexion_cat = obtener_conexion_categorias()
        cur_cat = conexion_cat.cursor(dictionary=True)
        cur_cat.execute("SELECT id, nombre FROM categorias")
        categorias_data = cur_cat.fetchall()
        cur_cat.close()
        conexion_cat.close()

        # Crear diccionario {id: nombre}
        nombres = { str(c['id']): c['nombre'] for c in categorias_data }

        # Total general de reportes
        total_reportes = sum(row['total'] for row in totals_by_cat) if totals_by_cat else 0

        # 3) Combinar nombre + total + porcentaje
        categorias = []
        for row in totals_by_cat:
            cid = str(row['categoria_id'])
            total = int(row['total'])
            nombre = nombres.get(cid, f"ID {cid}")
            porcentaje = round((total / total_reportes) * 100, 1) if total_reportes > 0 else 0
            categorias.append({
                'id': int(cid),
                'nombre': nombre,
                'total': total,
                'porcentaje': porcentaje
            })

        # Añadir categorías sin reportes (opcional)
        existentes = {c['id'] for c in categorias}
        for id_str, name in nombres.items():
            id_int = int(id_str)
            if id_int not in existentes:
                categorias.append({'id': id_int, 'nombre': name, 'total': 0, 'porcentaje': 0})

        # Ordenar por total descendente
        categorias = sorted(categorias, key=lambda x: x['total'], reverse=True)

        # Renderizar con datos
        return render_template(
            "paginas/dashboard.html",
            categorias=categorias,
            total_reportes=total_reportes
        )

    except Exception as e:
        print("Error en /dashboard:", e)
        return render_template("paginas/dashboard.html", categorias=[], total_reportes=0)


@dashboard_bp.route('/api/categoria/<int:categoria_id>/total')
def api_categoria_total(categoria_id):
    try:
        conexion = obtener_conexion_reportes_generales()
        cursor = conexion.cursor(dictionary=True)
        cursor.execute("SELECT COUNT(*) AS total FROM reportes WHERE categoria = %s", (categoria_id,))
        row = cursor.fetchone()
        cursor.close()
        conexion.close()
        total = int(row['total']) if row else 0
        return jsonify({'categoria_id': categoria_id, 'total': total})
    except Exception as e:
        print("Error en api_categoria_total:", e)
        return jsonify({'error': str(e)}), 500


@dashboard_bp.route('/api/categorias/totales')
def api_categorias_totales():
    try:
        conexion = obtener_conexion_reportes_generales()
        cursor = conexion.cursor(dictionary=True)
        cursor.execute("SELECT categoria AS categoria_id, COUNT(*) AS total FROM reportes GROUP BY categoria")
        totals = cursor.fetchall()
        cursor.close()
        conexion.close()
        return jsonify(totals)
    except Exception as e:
        print("Error en api_categorias_totales:", e)
        return jsonify({'error': str(e)}), 500


@dashboard_bp.route('/api/fallas_por_categoria')
def api_fallas_por_categoria():
    try:
        # 1) Obtener todos los reportes (solo los campos necesarios)
        conn_rep = obtener_conexion_reportes_generales()
        cur_rep = conn_rep.cursor(dictionary=True)
        cur_rep.execute("""
            SELECT categoria
            FROM reportes
            WHERE categoria IS NOT NULL
        """)
        reportes = cur_rep.fetchall()
        cur_rep.close()
        conn_rep.close()

        # 2) Contar por id de categoria
        conteo = {}
        for r in reportes:
            cat_id = r.get('categoria')
            # normalizar a str para keys consistentes
            key = str(cat_id) if cat_id is not None else None
            if key:
                conteo[key] = conteo.get(key, 0) + 1

        # 3) Obtener nombres de categorias desde la base categorias_fallas
        conn_cat = obtener_conexion_categorias()
        cur_cat = conn_cat.cursor(dictionary=True)
        cur_cat.execute("SELECT id, nombre FROM categorias")
        categorias_data = cur_cat.fetchall()
        cur_cat.close()
        conn_cat.close()

        # construir mapa id -> nombre
        map_cat = { str(c['id']): c['nombre'] for c in categorias_data }

        # 4) construir lista de resultados: si hay categorias sin reportes también podemos incluirlas con 0
        resultados = []
        # incluir todas las categorias (para que dashboard siempre muestre las 8)
        for cid, nombre in map_cat.items():
            resultados.append({
                "categoria_id": cid,
                "categoria": nombre,
                "cantidad": conteo.get(cid, 0)
            })

        # (opcional) si quieres sólo las categorías que tienen >0:
        # resultados = [ {"categoria_id":k, "categoria":map_cat.get(k,"(sin nombre)"), "cantidad":v} for k,v in conteo.items() ]

        return jsonify(resultados)

    except Exception as e:
        current_app.logger.exception("Error en api_fallas_por_categoria:")
        return jsonify({"error": str(e)}), 500
    

@dashboard_bp.route('/api/fallas_por_sede_categoria')
def fallas_por_sede_categoria():
    from conexion import obtener_conexion_reportes_generales
    try:
        con = obtener_conexion_reportes_generales()
        cur = con.cursor(dictionary=True)

        # --- Prueba 1: Verificar si la tabla existe ---
        cur.execute("SHOW TABLES;")
        tablas = [t[list(t.keys())[0]] for t in cur.fetchall()]
        print("Tablas encontradas:", tablas)

        # --- Prueba 2: Intentar consultar con nombres comunes ---
        consulta =consulta = """
            SELECT 
                s.nombre AS sede, 
                c.nombre AS categoria, 
                COUNT(r.id) AS cantidad
            FROM 
                reportes r
            JOIN 
                sedes_uneg.sedes s 
                ON r.sede = s.id  -- Asumo que 'r.sede' en reportes es el ID de la sede
            JOIN 
                categorias_fallas.categorias c 
                ON r.categoria = c.id -- Asumo que 'r.categoria' en reportes es el ID de la categoría
            GROUP BY 
                s.nombre, c.nombre
            ORDER BY 
                s.nombre, c.nombre;
        """
        cur.execute(consulta)
        resultados = cur.fetchall()

        print("Ejemplo de fila:", resultados[:3])  # ← imprimirá en consola Flask

        datos_agrupados = {}
        sedes = set()
        categorias = set()

        for fila in resultados:
            sede = fila["sede"]
            categoria = fila["categoria"]
            cantidad = fila["cantidad"]

            sedes.add(sede)
            categorias.add(categoria)

            if categoria not in datos_agrupados:
                datos_agrupados[categoria] = {}
            datos_agrupados[categoria][sede] = cantidad

        sedes_list = sorted(list(sedes))
        categorias_list = sorted(list(categorias))

        respuesta = {
            "sedes": sedes_list,
            "categorias": []
        }

        for categoria in categorias_list:
            datos_por_sede = {}
            for sede in sedes_list:
                datos_por_sede[sede] = datos_agrupados.get(categoria, {}).get(sede, 0)
            respuesta["categorias"].append({
                "nombre": categoria,
                "datosPorSede": datos_por_sede
            })

        cur.close()
        con.close()

        return jsonify(respuesta)

    except Exception as e:
        print(" Error en la consulta:", e)
        return jsonify({"error": "No se pudieron obtener los datos", "detalle": str(e)}), 500

