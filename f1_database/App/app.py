# app.py
from flask import Flask, render_template, request, redirect, url_for, session, flash
import psycopg2
import io # Necessário para ler o arquivo em memória

# --- Configuração e Conexão (sem alterações) ---
app = Flask(__name__)
app.secret_key = 'sua_chave_secreta_muito_segura' 

def conectar_bd():
    try:
        conn = psycopg2.connect(
            dbname="LabSQL",
            user="postgres",
            password="!Maebonita99",
            host="localhost",
            port="5432"
        )
        return conn
    except psycopg2.OperationalError as e:
        print(f"🚨 Erro ao conectar ao banco de dados: {e}")
        return None

# --- Rotas Principais (sem alterações) ---
# (Mantenha as rotas /login, /, /dashboard, /relatorio, /logout, e as de admin como estão)
# Em app.py

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        login = request.form['login']
        senha = request.form['password']
        conn = conectar_bd()
        if not conn:
            flash("Erro de conexão com o banco de dados.", "danger")
            return render_template('login.html')
        
        cursor = conn.cursor()
        cursor.execute(
            "SELECT UserID, Tipo, IdOriginal FROM USERS WHERE Login = %s AND Password = crypt(%s::text, Password);",
            (login, senha)
        )
        usuario = cursor.fetchone()
        
        if usuario:
            # --- ADIÇÃO IMPORTANTE AQUI ---
            # Insere o registro do evento de login no log
            try:
                user_id_log = usuario[0]
                cursor.execute(
                    "INSERT INTO Users_Log (UserID, EventType) VALUES (%s, 'login');", 
                    (user_id_log,)
                )
                conn.commit()
            except Exception as e:
                conn.rollback()
                print(f"Erro ao registrar log de login: {e}")
            # --- FIM DA ADIÇÃO ---

            session['loggedin'] = True
            session['userid'] = usuario[0]
            session['tipo'] = usuario[1]
            session['id_original'] = usuario[2]
            
            cursor.close()
            conn.close()
            
            flash('Login bem-sucedido!', 'success')
            return redirect(url_for('dashboard'))
        else:
            flash('Login ou senha inválidos.', 'danger')
            cursor.close()
            conn.close()
            
    return render_template('login.html')

# Em app.py

@app.route('/')
@app.route('/dashboard')
def dashboard():
    if 'loggedin' not in session: return redirect(url_for('login'))
    
    tipo_usuario = session['tipo']
    id_original = session.get('id_original')
    conn = conectar_bd()
    cursor = conn.cursor()

    if tipo_usuario == 'Administrador':
        # --- BUSCA DE DADOS PARA O DASHBOARD DO ADMIN ---
        
        # 1. Quantidades totais
        cursor.execute("SELECT COUNT(*) FROM Drivers;")
        total_pilotos = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM Constructors;")
        total_escuderias = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM Seasons;")
        total_temporadas = cursor.fetchone()[0]
        
        # Define o ano corrente
        ano_corrente = 2012 # O projeto é para o ano de 2025
        
        # 2. Lista de corridas do ano corrente
        query_races = """
            SELECT r.Name, res.Laps, res.Time 
            FROM Races r
            JOIN Results res ON r.RaceID = res.RaceID
            WHERE r.Year = %s AND res.Position = 1
            ORDER BY r.Date;
        """
        cursor.execute(query_races, (ano_corrente,))
        races_2025 = cursor.fetchall()
        
        # 3. Lista de escuderias e pontos no ano corrente
        query_constructors = """
            SELECT c.Name, SUM(res.Points) as total_points 
            FROM Constructors c
            JOIN Results res ON c.ConstructorID = res.ConstructorID
            JOIN Races r ON res.RaceID = r.RaceID
            WHERE r.Year = %s
            GROUP BY c.Name
            HAVING SUM(res.Points) > 0
            ORDER BY total_points DESC;
        """
        cursor.execute(query_constructors, (ano_corrente,))
        constructors_2025 = cursor.fetchall()

        # 4. Lista de pilotos e pontos no ano corrente
        query_pilots = """
            SELECT d.Forename || ' ' || d.Surname as pilot_name, SUM(res.Points) as total_points 
            FROM Drivers d
            JOIN Results res ON d.DriverID = res.DriverID
            JOIN Races r ON res.RaceID = r.RaceID
            WHERE r.Year = %s
            GROUP BY pilot_name
            HAVING SUM(res.Points) > 0
            ORDER BY total_points DESC;
        """
        cursor.execute(query_pilots, (ano_corrente,))
        pilots_2025 = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        return render_template(
            'dashboard_admin.html', 
            total_pilotos=total_pilotos, 
            total_escuderias=total_escuderias, 
            total_temporadas=total_temporadas,
            races_2025=races_2025,
            constructors_2025=constructors_2025,
            pilots_2025=pilots_2025,
            ano_corrente=ano_corrente
        )
        
    elif tipo_usuario == 'Escuderia':
        # --- BUSCA DE DADOS ATUALIZADA PARA O DASHBOARD DA ESCUDERIA ---
        
        # Nome da escuderia
        cursor.execute("SELECT Name FROM Constructors WHERE ConstructorID = %s;", (id_original,))
        nome_escuderia = cursor.fetchone()[0]
        
        # 1. Quantidade de vitórias da escuderia 
        cursor.execute("SELECT COUNT(*) FROM Results WHERE ConstructorID = %s AND Position = 1;", (id_original,))
        total_vitorias = cursor.fetchone()[0]
        
        # 2. Quantidade de pilotos diferentes 
        cursor.execute("SELECT COUNT(DISTINCT DriverID) FROM Results WHERE ConstructorID = %s;", (id_original,))
        qtd_pilotos = cursor.fetchone()[0]
        
        # 3. Primeiro e último ano na base 
        query_anos = """
            SELECT MIN(r.Year), MAX(r.Year) 
            FROM Results res
            JOIN Races r ON res.RaceID = r.RaceID
            WHERE res.ConstructorID = %s;
        """
        cursor.execute(query_anos, (id_original,))
        anos = cursor.fetchone()
        primeiro_ano = anos[0] or "N/A"
        ultimo_ano = anos[1] or "N/A"
        
        cursor.close()
        conn.close()
        
        return render_template(
            'dashboard_escuderia.html', 
            nome_escuderia=nome_escuderia, 
            total_vitorias=total_vitorias,
            qtd_pilotos=qtd_pilotos,
            primeiro_ano=primeiro_ano,
            ultimo_ano=ultimo_ano
        )

    elif tipo_usuario == 'Piloto':
        # --- BUSCA DE DADOS ATUALIZADA PARA O DASHBOARD DO PILOTO ---

        # Busca nome do piloto e sua última escuderia
        cursor.execute("""
            SELECT d.Forename || ' ' || d.Surname, c.Name
            FROM Drivers d LEFT JOIN Results res ON d.DriverID = res.DriverID LEFT JOIN Constructors c ON res.ConstructorID = c.ConstructorID
            WHERE d.DriverID = %s ORDER BY res.RaceID DESC LIMIT 1;
        """, (id_original,))
        resultado = cursor.fetchone()
        nome_piloto = resultado[0] if resultado else "Piloto"
        escuderia_piloto = resultado[1] if resultado and resultado[1] else 'Nenhuma'

        # 1. Busca o primeiro e último ano de atividade do piloto
        query_anos = """
            SELECT MIN(r.Year), MAX(r.Year) 
            FROM Results res
            JOIN Races r ON res.RaceID = r.RaceID
            WHERE res.DriverID = %s;
        """
        cursor.execute(query_anos, (id_original,))
        anos = cursor.fetchone()
        primeiro_ano = anos[0] or "N/A"
        ultimo_ano = anos[1] or "N/A"
        
        # 2. Busca o detalhamento de performance por ano e circuito
        query_performance = """
            SELECT
                r.Year,
                c.Name AS circuit_name,
                SUM(res.Points) AS total_points,
                SUM(CASE WHEN res.Position = 1 THEN 1 ELSE 0 END) AS total_wins,
                COUNT(res.ResultID) AS total_races
            FROM Results res
            JOIN Races r ON res.RaceID = r.RaceID
            JOIN Circuits c ON r.CircuitID = c.CircuitID
            WHERE res.DriverID = %s
            GROUP BY r.Year, c.Name
            ORDER BY r.Year DESC, total_points DESC;
        """
        cursor.execute(query_performance, (id_original,))
        performance_data = cursor.fetchall()

        cursor.close()
        conn.close()
        
        return render_template(
            'dashboard_piloto.html', 
            nome_piloto=nome_piloto, 
            escuderia_piloto=escuderia_piloto,
            primeiro_ano=primeiro_ano,
            ultimo_ano=ultimo_ano,
            performance_data=performance_data
        )
    
    return redirect(url_for('login'))

@app.route('/relatorio/<nome_funcao>')
def exibir_relatorio(nome_funcao):
    if 'loggedin' not in session: return redirect(url_for('login'))
    conn = conectar_bd()
    cursor = conn.cursor()
    titulo_relatorio, colunas, resultados = "Relatório", [], []
    id_param = session.get('id_original')
    user_type = session.get('tipo')

    # Relatórios do Admin
    if user_type == 'Administrador':
        if nome_funcao == 'admin_status_resultados':
            titulo_relatorio, colunas = "Resultados Gerais por Status", ["Status", "Quantidade"]
            cursor.execute("SELECT * FROM admin_relatorio_status_resultados();")
            resultados = cursor.fetchall()
        elif nome_funcao == 'admin_escuderias_totais':
            titulo_relatorio, colunas = "Total de Corridas por Escuderia", ["Nome da Escuderia", "Total de Corridas"]
            cursor.execute("SELECT * FROM admin_relatorio_escuderias_corridas_totais();")
            resultados = cursor.fetchall()
    
    # Relatórios da Escuderia
    elif user_type == 'Escuderia':
        if nome_funcao == 'escuderia_vitorias_pilotos':
            titulo_relatorio, colunas = "Vitórias dos Pilotos da Escuderia", ["Nome do Piloto", "Nº de Vitórias"]
            cursor.execute("SELECT * FROM escuderia_relatorio_vitorias_pilotos(%s);", (id_param,))
            resultados = cursor.fetchall()
        elif nome_funcao == 'escuderia_status':
            titulo_relatorio, colunas = "Resultados da Escuderia por Status", ["Status", "Quantidade"]
            cursor.execute("SELECT * FROM escuderia_relatorio_status(%s);", (id_param,))
            resultados = cursor.fetchall()

    # Relatórios do Piloto
    elif user_type == 'Piloto':
        if nome_funcao == 'piloto_pontos_por_ano':
            titulo_relatorio, colunas = "Pontos por Ano", ["Ano", "Nome da Corrida", "Pontos"]
            cursor.execute("SELECT * FROM piloto_relatorio_pontos_por_ano(%s);", (id_param,))
            resultados = cursor.fetchall()
        elif nome_funcao == 'piloto_status':
            titulo_relatorio, colunas = "Meus Resultados por Status", ["Status", "Quantidade"]
            cursor.execute("SELECT * FROM piloto_relatorio_status(%s);", (id_param,))
            resultados = cursor.fetchall()

    cursor.close()
    conn.close()
    return render_template('relatorio.html', titulo=titulo_relatorio, colunas=colunas, resultados=resultados)

@app.route('/admin/report/airports', methods=['GET', 'POST'])
def admin_report_airports():
    if 'loggedin' not in session or session['tipo'] != 'Administrador': return redirect(url_for('login'))
    
    if request.method == 'POST':
        nome_cidade = request.form['nome_cidade']
        conn = conectar_bd()
        cursor = conn.cursor()
        titulo_relatorio = f"Aeroportos Próximos de '{nome_cidade}'"
        colunas = ["Cidade na Base", "IATA", "Nome do Aeroporto", "Cidade do Aeroporto", "Distância (km)", "Tipo"]
        cursor.execute("SELECT * FROM admin_relatorio_aeroportos_proximos(%s);", (nome_cidade,))
        resultados = cursor.fetchall()
        cursor.close()
        conn.close()
        return render_template('relatorio.html', titulo=titulo_relatorio, colunas=colunas, resultados=resultados)

    return render_template('report_airports_form.html')


# Em app.py

@app.route('/logout')
def logout():
    # Verifica se o usuário estava logado para obter o ID
    if 'userid' in session:
        user_id = session['userid']
        conn = None
        try:
            # --- ADIÇÃO IMPORTANTE AQUI ---
            # Registra o evento de logout
            conn = conectar_bd()
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO Users_Log (UserID, EventType) VALUES (%s, 'logout');", 
                (user_id,)
            )
            conn.commit()
            cursor.close()
            conn.close()
        except Exception as e:
            print(f"Erro ao registrar log de logout: {e}")
            if conn:
                conn.rollback()
                cursor.close()
                conn.close()
        # --- FIM DA ADIÇÃO ---

    session.clear() # Limpa a sessão depois de registrar o log
    flash('Você foi desconectado.', 'info')
    return redirect(url_for('login'))

@app.route('/admin/add_constructor', methods=['POST'])
def add_constructor():
    if 'loggedin' not in session or session['tipo'] != 'Administrador': 
        return redirect(url_for('login'))
    
    conn = None
    try:
        constructor_id = request.form['id']
        constructor_ref = request.form['constructor_ref']
        name = request.form['name']
        nationality = request.form['nationality']
        url = request.form['url']
    
        conn = conectar_bd()
        cursor = conn.cursor()
        
        cursor.execute(
            "INSERT INTO Constructors (ConstructorID, ConstructorRef, Name, Nationality, URL) VALUES (%s, %s, %s, %s, %s);",
            (constructor_id, constructor_ref, name, nationality, url)
        )
        conn.commit()
        flash(f"Escuderia '{name}' (ID: {constructor_id}) cadastrada com sucesso!", "success")

    except Exception as e: 
        if conn:
            conn.rollback()
        flash(f"Erro ao cadastrar escuderia: {e}", "danger")

    finally:
        if conn:
            cursor.close()
            conn.close()
            
    return redirect(url_for('dashboard'))

@app.route('/admin/add_driver', methods=['POST'])
def add_driver():
    if 'loggedin' not in session or session['tipo'] != 'Administrador': return redirect(url_for('login'))
    driver_ref, number, code, forename, surname, dob, nationality, url = request.form['driver_ref'], request.form['number'] or None, request.form['code'], request.form['forename'], request.form['surname'], request.form['dob'], request.form['nationality'], request.form['url']
    try:
        conn = conectar_bd()
        cursor = conn.cursor()
        cursor.execute("INSERT INTO Drivers (DriverRef, Number, Code, Forename, Surname, DateOfBirth, Nationality, URL) VALUES (%s, %s, %s, %s, %s, %s, %s, %s);", (driver_ref, number, code, forename, surname, dob, nationality, url))
        conn.commit()
        flash(f"Piloto '{forename} {surname}' cadastrado com sucesso!", "success")
    except Exception as e: flash(f"Erro ao cadastrar piloto: {e}", "danger")
    finally:
        cursor.close()
        conn.close()
    return redirect(url_for('dashboard'))

# --- NOVAS ROTAS PARA AÇÕES DA ESCUDERIA ---

@app.route('/escuderia/consult_pilot', methods=['POST'])
def escuderia_consult_pilot():
    # Segurança: Apenas escuderias podem acessar
    if 'loggedin' not in session or session['tipo'] != 'Escuderia':
        return redirect(url_for('login'))
    
    forename = request.form['forename']
    constructor_id = session['id_original']
    
    conn = conectar_bd()
    cursor = conn.cursor()
    
    # SQL que busca pilotos com o 'forename' que já correram pela escuderia logada
    query = """
        SELECT DISTINCT d.Forename || ' ' || d.Surname, d.DateOfBirth, d.Nationality
        FROM Drivers d
        JOIN Results res ON d.DriverID = res.DriverID
        WHERE d.Forename ILIKE %s AND res.ConstructorID = %s;
    """
    
    cursor.execute(query, (f"%{forename}%", constructor_id))
    resultados = cursor.fetchall()
    
    titulo_relatorio = f"Pilotos com o nome '{forename}' que correram pela sua escuderia"
    colunas = ["Nome Completo", "Data de Nascimento", "Nacionalidade"]
    
    cursor.close()
    conn.close()
    
    # Reutiliza o template de relatório para exibir os resultados
    return render_template('relatorio.html', titulo=titulo_relatorio, colunas=colunas, resultados=resultados)


@app.route('/escuderia/upload_pilots', methods=['POST'])
def escuderia_upload_pilots():
    # Segurança e verificação do arquivo
    if 'loggedin' not in session or session['tipo'] != 'Escuderia':
        return redirect(url_for('login'))
    if 'pilot_file' not in request.files or request.files['pilot_file'].filename == '':
        flash('Nenhum arquivo selecionado.', 'warning')
        return redirect(url_for('dashboard'))

    file = request.files['pilot_file']
    
    # Processa o arquivo
    conn = conectar_bd()
    cursor = conn.cursor()
    
    # Envolve a leitura em um wrapper para tratar como texto
    file_wrapper = io.TextIOWrapper(file, encoding='utf-8')
    
    pilotos_adicionados = 0
    pilotos_ignorados = 0
    
    for line in file_wrapper:
        try:
            # Assumindo que o arquivo é um CSV: DriverID,DriverRef,Number,Code,Forename,Surname,DOB,Nationality,URL
            data = line.strip().split(',')
            driver_id, driver_ref, number, code, forename, surname, dob, nationality, url = data

            # 1. Verifica se o piloto já existe pelo nome completo 
            cursor.execute("SELECT DriverID FROM Drivers WHERE Forename = %s AND Surname = %s;", (forename, surname))
            if cursor.fetchone():
                pilotos_ignorados += 1
                continue # Pula para a próxima linha

            # 2. Se não existe, insere o novo piloto 
            # O trigger cuidará da criação na tabela USERS
            cursor.execute(
                """
                INSERT INTO Drivers (DriverID, DriverRef, Number, Code, Forename, Surname, DateOfBirth, Nationality, URL)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s);
                """,
                (driver_id, driver_ref, number or None, code, forename, surname, dob, nationality, url)
            )
            pilotos_adicionados += 1
        
        except Exception as e:
            conn.rollback() # Desfaz a inserção se houver erro nesta linha
            flash(f"Erro ao processar linha: {line.strip()}. Erro: {e}", "danger")
            continue # Continua com as próximas linhas

    conn.commit()
    cursor.close()
    conn.close()

    flash(f"Processamento concluído: {pilotos_adicionados} piloto(s) adicionado(s), {pilotos_ignorados} piloto(s) ignorado(s) (já existiam).", "success")
    return redirect(url_for('dashboard'))

# --- Fim das Novas Rotas ---

if __name__ == '__main__':
    app.run(debug=True)