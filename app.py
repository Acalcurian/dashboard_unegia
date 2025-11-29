from flask_mail import Mail, Message
from werkzeug.utils import secure_filename
from flask import Flask, render_template, request, redirect, url_for, flash, jsonify
import psycopg2
import psycopg2.extras
import os
from conexion import obtener_conexion, obtener_conexion_categorias, obtener_conexion_departamentos_db, obtener_conexion_reportes_generales
from dashboard_router import dashboard_bp
from dotenv import load_dotenv
import requests
import psycopg2.extras
from PIL import Image
from PIL.ExifTags import TAGS, GPSTAGS


# Cargar variables del archivo .env
load_dotenv()

app = Flask(__name__)
app.secret_key = "12345"
app.register_blueprint(dashboard_bp)


# -------------------------------
# CONFIGURACIÓN DE CORREO
# -------------------------------
app.config['MAIL_SERVER'] = os.getenv('MAIL_SERVER')
app.config['MAIL_PORT'] = int(os.getenv('MAIL_PORT'))
app.config['MAIL_USE_TLS'] = os.getenv('MAIL_USE_TLS') == 'True'
app.config['MAIL_USERNAME'] = os.getenv('MAIL_USERNAME')
app.config['MAIL_PASSWORD'] = os.getenv('MAIL_PASSWORD')
app.config['MAIL_DEFAULT_SENDER'] = os.getenv('MAIL_USERNAME')

mail = Mail(app)



# Carpeta donde se guardarán las fotos
UPLOAD_FOLDER = 'static/uploads'
app.config['UPLOAD_FOLDER'] = os.path.join('static', 'uploads')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Tamaño máximo permitido (500 MB)
app.config['MAX_CONTENT_LENGTH'] = 500 * 1024 * 1024

# Extensiones permitidas
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'webp'}


def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


# -----------------------------------------------------
# INDEX Y FORMULARIO
# -----------------------------------------------------

@app.route('/')
def index():
    conexion_cat = obtener_conexion_categorias()
    cursor_cat = conexion_cat.cursor(cursor_factory=psycopg2.extras.DictCursor)
    cursor_cat.execute("SELECT id, inf FROM categorias")
    categorias_inf = cursor_cat.fetchall()
    cursor_cat.close()
    conexion_cat.close()

    categorias = [
        {"id": 1, "nombre": "Electricos", "imagen": "electrico.png"},
        {"id": 2, "nombre": "Plomeria", "imagen": "plomeria.png"},
        {"id": 3, "nombre": "Refrigeracion", "imagen": "refrigeracion.png"},
        {"id": 4, "nombre": "Seguridad", "imagen": "seguridad.png"},
        {"id": 5, "nombre": "Infraestructura", "imagen": "infraestructura.png"},
        {"id": 6, "nombre": "Mobiliario", "imagen": "mobiliario.png"},
        {"id": 7, "nombre": "Suministros", "imagen": "suministros.png"},
        {"id": 8, "nombre": "Tecnologicos", "imagen": "tecnologico.png"},
    ]

    for cat in categorias:
        for inf_data in categorias_inf:
            if cat["id"] == inf_data["id"]:
                cat["inf"] = inf_data["inf"]
                break

    categoria_id = request.args.get('categoria_id', type=int)
    categoria = None
    if categoria_id:
        conexion_cat = obtener_conexion_categorias()
        cursor_cat = conexion_cat.cursor(cursor_factory=psycopg2.extras.DictCursor)
        cursor_cat.execute("SELECT inf FROM categorias WHERE id = %s", (categoria_id,))
        categoria = cursor_cat.fetchone()
        cursor_cat.close()
        conexion_cat.close()

    return render_template('paginas/index.html', categorias=categorias, categoria=categoria)


@app.route('/formulario')
def formulario():
    categoria_id = request.args.get('categoria_id', type=int)

    conexion = obtener_conexion()
    cursor = conexion.cursor(cursor_factory=psycopg2.extras.DictCursor)
    cursor.execute("SELECT id, nombre FROM sedes")
    sedes = cursor.fetchall()
    cursor.close()
    conexion.close()

    conexion_cat = obtener_conexion_categorias()
    cursor_cat = conexion_cat.cursor(cursor_factory=psycopg2.extras.DictCursor)
    cursor_cat.execute("SELECT id, nombre, inf FROM categorias WHERE id = %s", (categoria_id,))
    categoria = cursor_cat.fetchone()
    cursor_cat.execute("SELECT id, descripcion, inf FROM fallas WHERE categoria_id = %s", (categoria_id,))
    fallas = cursor_cat.fetchall()
    cursor_cat.close()
    conexion_cat.close()

    return render_template('paginas/formulario.html', sedes=sedes, categoria=categoria, fallas=fallas)


@app.route("/obtener_fallas/<int:categoria_id>")
def obtener_fallas(categoria_id):
    conexion = obtener_conexion_categorias()
    cursor = conexion.cursor(cursor_factory=psycopg2.extras.DictCursor)
    cursor.execute("SELECT id, descripcion FROM fallas WHERE categoria_id = %s", (categoria_id,))
    fallas = cursor.fetchall()
    cursor.close()
    conexion.close()
    return jsonify(fallas)


# -----------------------------------------------------
# REPORTES - LISTAR
# -----------------------------------------------------

@app.route('/reportes', methods=['GET'])
def reportes():
    cedula = request.args.get('cedula')
    reportes_usuario = []

    if cedula:
        try:
            print(f"\nConsultando reportes para la cédula: {cedula}")

            conexion = obtener_conexion_reportes_generales()
            cursor = conexion.cursor(cursor_factory=psycopg2.extras.DictCursor)
            cursor.execute("""
                SELECT id, cedula, categoria, tipo_falla, sede, foto_path, descripcion, fecha_reporte
                FROM reportes
                WHERE cedula = %s
                ORDER BY fecha_reporte DESC
            """, (cedula,))
            reportes_usuario = cursor.fetchall()
            cursor.close()
            conexion.close()

            conexion_cat = obtener_conexion_categorias()
            cursor_cat = conexion_cat.cursor(cursor_factory=psycopg2.extras.DictCursor)
            cursor_cat.execute("SELECT id, nombre FROM categorias")
            categorias_data = cursor_cat.fetchall()
            cursor_cat.execute("SELECT id, descripcion AS nombre FROM fallas")
            fallas_data = cursor_cat.fetchall()
            cursor_cat.close()
            conexion_cat.close()

            conexion_sedes = obtener_conexion()
            cursor_sedes = conexion_sedes.cursor(cursor_factory=psycopg2.extras.DictCursor)
            cursor_sedes.execute("SELECT id, nombre FROM sedes")
            sedes_data = cursor_sedes.fetchall()
            cursor_sedes.close()
            conexion_sedes.close()

            categorias = {str(c['id']).strip(): c['nombre'] for c in categorias_data}
            fallas = {str(f['id']).strip(): f['nombre'] for f in fallas_data}
            sedes = {str(s['id']).strip(): s['nombre'] for s in sedes_data}

            for rep in reportes_usuario:
                cat_id = str(rep.get('categoria')) if rep.get('categoria') is not None else None
                falla_id = str(rep.get('tipo_falla')) if rep.get('tipo_falla') is not None else None
                sede_id = str(rep.get('sede')) if rep.get('sede') is not None else None
                rep['categoria'] = categorias.get(cat_id, f"(Sin nombre, ID={cat_id})") if cat_id else "(N/D)"
                rep['tipo_falla'] = fallas.get(falla_id, f"(Sin nombre, ID={falla_id})") if falla_id else "(N/D)"
                rep['sede'] = sedes.get(sede_id, f"(Sin nombre, ID={sede_id})") if sede_id else "(N/D)"

        except Exception as e:
            flash(f"Error al obtener reportes: {e}", "danger")
            print(f" Error en reportes(): {e}")

    return render_template("paginas/reportes.html", cedula=cedula, reportes=reportes_usuario)


# -----------------------------------------------------
# ENVIAR REPORTE
# -----------------------------------------------------
@app.route('/enviar_reporte', methods=['POST'])
def enviar_reporte():
    cedula = request.form.get('cedula')
    categoria_id = request.form.get('categoria')
    falla_id = request.form.get('falla_id')
    otra_falla = request.form.get('otra_falla')
    sede_id = request.form.get('sede')
    foto = request.files.get('foto_path')
    descripcion = request.form.get('descripcion')


    upload_folder = os.path.join(app.root_path, 'static', 'uploads')
    os.makedirs(upload_folder, exist_ok=True)

    foto_path = None

    if foto and allowed_file(foto.filename):
        filename = secure_filename(foto.filename)
        nombre_foto = f"{cedula}_{filename}"
        ruta_foto_completa = os.path.join(upload_folder, nombre_foto)
        foto.save(ruta_foto_completa)
        foto_path = f"uploads/{nombre_foto}"

    try:
        conexion = obtener_conexion_reportes_generales()
        cursor = conexion.cursor()

        # ⬅️ SQL ACTUALIZADO PARA GUARDAR COORDENADAS
        sql = """
        INSERT INTO reportes 
        (cedula, categoria, tipo_falla, fallas_otros, sede, foto_path, descripcion, lat_foto, lon_foto)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """

        # ⬅️ COLOCAMOS LOS VALORES SIN CAMBIAR NADA MÁS
        valores = (
            cedula, categoria_id, falla_id, otra_falla, 
            sede_id, foto_path, descripcion, lat_foto, lon_foto
        )

        cursor.execute(sql, valores)
        conexion.commit()
        cursor.close()
        conexion.close()

        try:
            # Llamar a la API de correo
            requests.post(
                "http://127.0.0.1:5000/api/enviar_correo",
                json={
                    "cedula": cedula,
                    "categoria_id": categoria_id,
                    "falla_id": falla_id,
                    "sede_id": sede_id,
                    "descripcion": descripcion,
                    "foto_path": foto_path
                }
            )
        except Exception as e:
            print(f"Error al llamar a la API de correo: {e}")

        flash("Reporte guardado correctamente con imagen.", "success")

    except Exception as e:
        flash(f"Error al guardar el reporte: {e}", "danger")
        print(f"Error al guardar reporte: {e}")

    return redirect(url_for('index', categoria_id=categoria_id))

# -----------------------------------------------------
# EDITAR REPORTE
# -----------------------------------------------------

@app.route('/editar_reporte/<int:reporte_id>', methods=['GET', 'POST'])
def editar_reporte(reporte_id):
    conexion = obtener_conexion_reportes_generales()
    cursor = conexion.cursor(cursor_factory=psycopg2.extras.DictCursor)
    cursor.execute("SELECT * FROM reportes WHERE id = %s", (reporte_id,))
    reporte = cursor.fetchone()
    cursor.close()
    conexion.close()

    if not reporte:
        flash("Reporte no encontrado.", "warning")
        return redirect(url_for('reportes'))

    conexion_cat_nombre = obtener_conexion_categorias()
    cursor_cat_nombre = conexion_cat_nombre.cursor(cursor_factory=psycopg2.extras.DictCursor)
    cursor_cat_nombre.execute("SELECT nombre FROM categorias WHERE id = %s", (reporte['categoria'],))
    categoria_nombre = cursor_cat_nombre.fetchone()
    cursor_cat_nombre.close()
    conexion_cat_nombre.close()

    conexion_cat = obtener_conexion_categorias()
    cursor_cat = conexion_cat.cursor(cursor_factory=psycopg2.extras.DictCursor)
    cursor_cat.execute("SELECT id, descripcion FROM fallas WHERE categoria_id = %s", (reporte['categoria'],))
    fallas = cursor_cat.fetchall()
    cursor_cat.close()
    conexion_cat.close()

    conexion_sede = obtener_conexion()
    cursor_sede = conexion_sede.cursor(cursor_factory=psycopg2.extras.DictCursor)
    cursor_sede.execute("SELECT id, nombre FROM sedes")
    sedes = cursor_sede.fetchall()
    cursor_sede.close()
    conexion_sede.close()

    if request.method == 'POST':
        nueva_falla = request.form.get('falla')
        nueva_sede = request.form.get('sede')
        nueva_descripcion = request.form.get('descripcion')
        nueva_foto = request.files.get('foto_path')

        if nueva_foto and allowed_file(nueva_foto.filename):
            if reporte['foto_path']:
                ruta_anterior = os.path.join(app.static_folder, reporte['foto_path'])
                if os.path.exists(ruta_anterior):
                    os.remove(ruta_anterior)
            filename = secure_filename(nueva_foto.filename)
            nombre_foto = f"{reporte['cedula']}_{filename}"
            ruta_foto = os.path.join(app.config['UPLOAD_FOLDER'], nombre_foto)
            nueva_foto.save(ruta_foto)
            ruta_relativa = os.path.join('uploads', nombre_foto).replace("\\", "/")
        else:
            ruta_relativa = reporte['foto_path']

        conexion_upd = obtener_conexion_reportes_generales()
        cursor_upd = conexion_upd.cursor()
        sql = """
        UPDATE reportes
        SET tipo_falla = %s, sede = %s, descripcion = %s, foto_path = %s
        WHERE id = %s
        """
        cursor_upd.execute(sql, (nueva_falla, nueva_sede, nueva_descripcion, ruta_relativa, reporte_id))
        conexion_upd.commit()
        cursor_upd.close()
        conexion_upd.close()

        flash("Reporte actualizado correctamente.", "success")
        return redirect(url_for('reportes', cedula=reporte['cedula']))

    foto_url = url_for('static', filename=reporte['foto_path']) if reporte['foto_path'] else None

    return render_template(
        "paginas/editar_reporte.html",
        reporte=reporte,
        fallas=fallas,
        sedes=sedes,
        categoria_nombre=categoria_nombre['nombre'] if categoria_nombre else 'Sin categoría',
        foto_url=foto_url
    )


# -----------------------------------------------------
# BORRAR REPORTE
# -----------------------------------------------------

@app.route('/borrar_reporte/<int:reporte_id>', methods=['POST'])
def borrar_reporte(reporte_id):
    try:
        conexion = obtener_conexion_reportes_generales()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.DictCursor)
        cursor.execute("SELECT foto_path, cedula FROM reportes WHERE id = %s", (reporte_id,))
        reporte = cursor.fetchone()

        if not reporte:
            cursor.close()
            conexion.close()
            flash("Reporte no encontrado.", "warning")
            return redirect(url_for('reportes'))

        foto_path = reporte.get('foto_path')
        cedula = reporte.get('cedula')

        cursor.execute("DELETE FROM reportes WHERE id = %s", (reporte_id,))
        conexion.commit()
        cursor.close()
        conexion.close()

        if foto_path:
            ruta_rel = str(foto_path).lstrip('/')
            if not ruta_rel.startswith('uploads/'):
                ruta_rel = os.path.join('uploads', ruta_rel)
            ruta_absoluta = os.path.join(app.static_folder, ruta_rel)
            if os.path.exists(ruta_absoluta):
                os.remove(ruta_absoluta)

        flash("Reporte eliminado correctamente.", "success")

    except Exception as e:
        flash(f"Error al eliminar el reporte: {e}", "danger")
        print("Error en borrar_reporte:", e)

    return redirect(url_for('reportes', cedula=cedula if 'cedula' in locals() and cedula else None))


# -----------------------------------------------------
#API DE DASHBOARD
# -----------------------------------------------------

@app.route('/api/fallas_por_sede_categoria')
def fallas_por_sede_categoria():
    try:
        conexion = obtener_conexion_reportes_generales()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.DictCursor)
        query = """
        SELECT 
            s.nombre AS sede,
            c.nombre AS categoria,
            COUNT(r.id) AS cantidad
        FROM reportes r
        JOIN sedes s ON r.sede = s.id
        JOIN categorias c ON r.categoria = c.id
        GROUP BY s.nombre, c.nombre
        ORDER BY s.nombre, c.nombre
        """
        cursor.execute(query)
        resultados = cursor.fetchall()
        cursor.close()
        conexion.close()

        sedes = sorted(list({fila['sede'] for fila in resultados}))
        categorias = sorted(list({fila['categoria'] for fila in resultados}))
        valores = []
        for sede in sedes:
            fila = []
            for categoria in categorias:
                coincidencia = next((f for f in resultados if f['sede'] == sede and f['categoria'] == categoria), None)
                fila.append(coincidencia['cantidad'] if coincidencia else 0)
            valores.append(fila)

        return jsonify({
            "sedes": sedes,
            "categorias": categorias,
            "valores": valores
        })

    except Exception as e:
        print("Error en fallas_por_sede_categoria:", e)
        return jsonify({"error": str(e)}), 500


@app.route('/api/categorias')
def obtener_categorias():
    try:
        conexion = obtener_conexion_categorias()
        cursor = conexion.cursor(cursor_factory=psycopg2.extras.DictCursor)
        cursor.execute("SELECT nombre FROM categorias ORDER BY nombre ASC")
        categorias = [fila['nombre'] for fila in cursor.fetchall()]
        cursor.close()
        conexion.close()
        return jsonify({"categorias": categorias})
    except Exception as e:
        print("Error en /api/categorias:", e)
        return jsonify({"error": str(e)}), 500




@app.route('/api/enviar_correo', methods=['POST'])
def api_enviar_correo():
    data = request.json

    try:
        # Datos del reporte
        cedula = data.get('cedula')
        categoria_id = data.get('categoria_id')
        falla_id = data.get('falla_id')
        sede_id = data.get('sede_id')
        descripcion = data.get('descripcion')
        foto_path = data.get('foto_path')
        reporte_id = data.get('reporte_id')  # Opcional, si lo envías desde el frontend

        destinatario = "acalcurian671@gmail.com"
        asunto = "Nuevo Reporte Registrado"

        # ------------------------------------------------------
        # Guardar primero el correo en la base de datos
        # ------------------------------------------------------
        correo_id = None
        try:
            conexion = obtener_conexion_departamentos_db()
            cursor = conexion.cursor()

            sql = """
            INSERT INTO correos_enviados 
            (reporte_id, cedula, destinatario, asunto, mensaje, foto_path, estatus_confirmacion)
            VALUES (%s, %s, %s, %s, %s, %s, FALSE)
            RETURNING id
            """
            valores = (
                reporte_id,
                cedula,
                destinatario,
                asunto,
                descripcion,
                foto_path
            )

            cursor.execute(sql, valores)
            correo_id = cursor.fetchone()[0]  # ✅ Obtenemos el ID del correo
            conexion.commit()
            cursor.close()
            conexion.close()
            print(f" Registro guardado en correos_enviados correctamente (ID: {correo_id})")

        except Exception as db_error:
            print(f" Error al guardar correo en la base de datos: {db_error}")

        # ------------------------------------------------------
        # Construcción del correo
        # ------------------------------------------------------
        msg = Message(
            subject=asunto,
            recipients=[destinatario],
        )

        # Cuerpo con botón de confirmación que incluye el ID real
        msg.html = f"""
        <h2>📋 Nuevo reporte recibido</h2>
        <p><b>Cédula:</b> {cedula}</p>
        <p><b>Categoría:</b> {categoria_id}</p>
        <p><b>Falla:</b> {falla_id}</p>
        <p><b>Sede:</b> {sede_id}</p>
        <p><b>Descripción:</b> {descripcion}</p>
        <br>
        {'<img src="cid:foto_reporte">' if foto_path else '<p>Sin imagen adjunta</p>'}
        <br>
        <p>Por favor confirma la recepción del correo:</p>
        <a href="http://127.0.0.1:5000/confirmar_recepcion?correo_id={correo_id}" 
           style="background-color:#4CAF50;color:white;padding:10px 20px;
           text-decoration:none;border-radius:5px;">Confirmar Recepción ✅</a>
        """


        

        # Adjuntar imagen si existe
        if foto_path:
            with app.open_resource(os.path.join('static', foto_path)) as fp:
                msg.attach(
                    "reporte.jpg",
                    "image/jpeg",
                    fp.read(),
                    disposition='inline',
                    headers={"Content-ID": "<foto_reporte>"}
                )

        # Enviar el correo
        mail.send(msg)
        print("Correo enviado correctamente")

        return jsonify({"success": True, "message": "Correo enviado y registrado correctamente"}), 200

    except Exception as e:
        print(f"Error al enviar correo: {e}")
        return jsonify({"success": False, "message": str(e)}), 500

    



@app.route('/confirmar_recepcion', methods=['GET'])
def confirmar_recepcion():
    correo_id = request.args.get('correo_id')

    if not correo_id:
        return "Faltan datos para confirmar.", 400

    try:
        conexion = obtener_conexion_departamentos_db()
        cursor = conexion.cursor()
        cursor.execute("UPDATE correos_enviados SET estatus_confirmacion = TRUE WHERE id = %s", (correo_id,))
        conexion.commit()
        cursor.close()
        conexion.close()
        print(f"✅ Confirmación registrada para correo ID: {correo_id}")

        # No redirige, solo muestra mensaje simple
        return """
        <html>
        <head><title>Confirmación</title></head>
        <body style="font-family:Arial;text-align:center;margin-top:50px;">
            <h2 style="color:green;">✅ Confirmación registrada correctamente</h2>
            <p>El estatus del correo ha sido actualizado.</p>
            <p>Ya puedes cerrar esta pestaña.</p>
        </body>
        </html>
        """

    except Exception as e:
        print(f"Error al confirmar recepción: {e}")
        return f"Error al confirmar recepción: {e}", 500  #estaos son mis enviar correo y confirmar correo realiza las implemetnaciones sin cambiar mas nada





@app.route('/dashboard_admin')
def dashboard_admin():
    conexion = obtener_conexion_departamentos_db()
    cursor = conexion.cursor()

    cursor.execute("""
        SELECT id, reporte_id, cedula, destinatario, asunto, mensaje, foto_path,
               estatus_confirmacion, estatus_solucion
        FROM correos_enviados
        ORDER BY id DESC
    """)

    correos = cursor.fetchall()
    cursor.close()
    conexion.close()

    lista = []
    for c in correos:
        lista.append({
            "id": c[0],
            "reporte_id": c[1],
            "cedula": c[2],
            "destinatario": c[3],
            "asunto": c[4],
            "mensaje": c[5],
            "foto_path": c[6],
            "estatus_confirmacion": c[7],
            "estatus_solucion": c[8],
        })

    return render_template("paginas/dashboard_admin.html", correos=lista)




@app.route("/marcar_solucionado/<int:correo_id>", methods=["POST"])
def marcar_solucionado(correo_id):
    try:
        conexion = obtener_conexion_departamentos_db()
        cursor = conexion.cursor()

        cursor.execute("""
            UPDATE correos_enviados
            SET estatus_solucion = TRUE
            WHERE id = %s
        """, (correo_id,))

        conexion.commit()
        cursor.close()
        conexion.close()

        return jsonify({"success": True}), 200

    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
    




@app.route('/dashboard_admin/confirmados')
def dashboard_admin_confirmados():
    conexion = obtener_conexion_departamentos_db()
    cursor = conexion.cursor()

    cursor.execute("""
        SELECT id, reporte_id, cedula, destinatario, asunto, mensaje, foto_path,
               estatus_confirmacion, estatus_solucion
        FROM correos_enviados
        WHERE estatus_confirmacion = TRUE
        ORDER BY id DESC
    """)

    correos = cursor.fetchall()
    cursor.close()
    conexion.close()

    lista = []
    for c in correos:
        lista.append({
            "id": c[0],
            "reporte_id": c[1],
            "cedula": c[2],
            "destinatario": c[3],
            "asunto": c[4],
            "mensaje": c[5],
            "foto_path": c[6],
            "estatus_confirmacion": c[7],
            "estatus_solucion": c[8],
        })

    return render_template("paginas/dashboard_admin.html", correos=lista)



@app.route('/dashboard_admin/no_confirmados')
def dashboard_admin_no_confirmados():
    conexion = obtener_conexion_departamentos_db()
    cursor = conexion.cursor()

    cursor.execute("""
        SELECT id, reporte_id, cedula, destinatario, asunto, mensaje, foto_path,
               estatus_confirmacion, estatus_solucion
        FROM correos_enviados
        WHERE estatus_confirmacion = FALSE
        ORDER BY id DESC
    """)

    correos = cursor.fetchall()
    cursor.close()
    conexion.close()

    lista = []
    for c in correos:
        lista.append({
            "id": c[0],
            "reporte_id": c[1],
            "cedula": c[2],
            "destinatario": c[3],
            "asunto": c[4],
            "mensaje": c[5],
            "foto_path": c[6],
            "estatus_confirmacion": c[7],
            "estatus_solucion": c[8],
        })

    return render_template("paginas/dashboard_admin.html", correos=lista)



# -----------------------------------------------------
# MAIN
# -----------------------------------------------------

if __name__ == '__main__':
    if not os.path.exists(UPLOAD_FOLDER):
        os.makedirs(UPLOAD_FOLDER)
    app.run(debug=True)
