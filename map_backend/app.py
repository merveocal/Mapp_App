from flask import Flask, jsonify, request
from flask_cors import CORS
import psycopg2

app = Flask(__name__)
CORS(app)  # Flutter için CORS izni

# PostgreSQL bağlantı bilgileri
db_config = {
    'dbname': 'map_app',
    'user': 'postgres',
    'password': 'PostgreSQL6232',
    'host': 'localhost',
    'port': '5432'
}

# Ana sayfa için basit route
@app.route('/')
def home():
    return "API çalışıyor"

@app.route('/users', methods=['GET'])
def get_users():
    try:
        conn = psycopg2.connect(**db_config)
        cur = conn.cursor()
        cur.execute("SELECT id, username FROM users2")
        users = cur.fetchall()

        users_list = [{'id': user[0], 'name': user[1]} for user in users]

        cur.close()
        conn.close()

        return jsonify(users_list)

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/locations', methods=['GET'])
def get_locations():
    user_id = request.args.get('user_id')  # ?user_id=1 gibi

    try:
        conn = psycopg2.connect(**db_config)
        cur = conn.cursor()

        if user_id:
            cur.execute("SELECT id, name, latitude, longitude, user_id FROM positions2 WHERE user_id = %s", (user_id,))
        else:
            cur.execute("SELECT id, name, latitude, longitude, user_id FROM positions2")

        rows = cur.fetchall()

        locations = []
        for row in rows:
            locations.append({
                'id': row[0],
                'name': row[1],
                'latitude': row[2],
                'longitude': row[3],
                'user_id': row[4]
            })

        cur.close()
        conn.close()
        return jsonify(locations)

    except Exception as e:
        return jsonify({'error': str(e)}), 500
        
@app.route('/add_user', methods=['POST'])
def add_user():
    data = request.get_json()
    username = data.get('username')

    if not username:
        return jsonify({'error': 'İsim eksik'}), 400

    try:
        conn = psycopg2.connect(**db_config)
        cur = conn.cursor()
        cur.execute("INSERT INTO users2 (username) VALUES (%s)", (username,))
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({'message': 'Kullanıcı eklendi'}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

        

# Kullanıcı silme
@app.route('/users/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    try:
        conn = psycopg2.connect(**db_config)
        cur = conn.cursor()
        cur.execute("DELETE FROM users2 WHERE id= %s", (user_id,))
        conn.commit()
        
        cur.close()
        conn.close()
        
        return '', 204
    except Exception as e:
        return jsonify({'error': str(e)}),500
        


@app.route('/add_marker', methods=['POST'])
def add_marker():
    data = request.get_json()
    user_id = data.get('user_id')
    name = data.get('name', '')
    latitude = data.get('latitude')
    longitude = data.get('longitude')

    if user_id is None or latitude is None or longitude is None:
        return jsonify({'error': 'Eksik veri'}), 400

    try:
        conn = psycopg2.connect(**db_config)
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO positions2 (user_id, name, latitude, longitude) VALUES (%s, %s, %s, %s)",
            (user_id, name, latitude, longitude)
        )
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({'message': 'Marker kaydedildi'}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

        
if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)

