from flask import Flask, jsonify, request
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime, timedelta, timezone

app = Flask(__name__)
CORS(app)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///parking.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

# --- TABELE ---
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100))
    email = db.Column(db.String(100), unique=True)
    password_hash = db.Column(db.String(200))
    nfc_uid = db.Column(db.String(50))

class ParkingSpot(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    status = db.Column(db.String(20), default='slobodno')

class Reservation(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'))
    spot_id = db.Column(db.Integer, db.ForeignKey('parking_spot.id'))
    expire_time = db.Column(db.DateTime)

# Kreiranje tabela i inicijalizacija
with app.app_context():
    db.create_all()
    if ParkingSpot.query.count() == 0:
        pocetna_mesta = [ParkingSpot(status='slobodno') for _ in range(4)]
        db.session.add_all(pocetna_mesta)
        db.session.commit()
        print("Baza inicijalizovana.")

# --- FUNKCIJE ZA LOGIKU ---
def ocisti_istekle():
    sada = datetime.now()
    istekle = Reservation.query.filter(Reservation.expire_time < sada).all()
    for rez in istekle:
        mesto = ParkingSpot.query.get(rez.spot_id)
        if mesto:
            mesto.status = 'slobodno'
        db.session.delete(rez)
    db.session.commit()

# --- RUTE ---
@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    if User.query.filter_by(email=data['email']).first():
        return jsonify({"message": "Email već postoji!"}), 400
    hashed_pw = generate_password_hash(data['password'])
    new_user = User(name=data['name'], email=data['email'], password_hash=hashed_pw, nfc_uid=data.get('nfc_uid'))
    db.session.add(new_user)
    db.session.commit()
    return jsonify({"message": "Korisnik kreiran!"})

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    user = User.query.filter_by(email=data['email']).first()
    if user and check_password_hash(user.password_hash, data['password']):
        return jsonify({"message": "Login uspešan", "user_id": user.id})
    return jsonify({"message": "Pogrešni podaci"}), 401

@app.route('/parking-status', methods=['GET'])
def get_status():
    ocisti_istekle() 
    mesta = ParkingSpot.query.all()
    return jsonify([{"id": m.id, "status": m.status} for m in mesta])

@app.route('/rezervisi', methods=['POST'])
def rezervisi():
    data = request.get_json()
    user_id = data.get('user_id')
    spot_id = data.get('spot_id')
    
    # Provera da li korisnik već ima rezervaciju
    if Reservation.query.filter_by(user_id=user_id).first():
        return jsonify({"status": "error", "poruka": "Već imaš aktivnu rezervaciju!"}), 400
        
    mesto = ParkingSpot.query.get(spot_id)
    if mesto and mesto.status == 'slobodno':
        mesto.status = 'rezervisano'
        expire_time = datetime.now(timezone.utc) + timedelta(minutes=15)
        nova_rez = Reservation(user_id=user_id, spot_id=spot_id, expire_time=expire_time)
        db.session.add(nova_rez)
        db.session.commit()
        return jsonify({"status": "success"})
    return jsonify({"status": "error", "poruka": "Mesto nije dostupno"}), 400

@app.route('/profil/<int:user_id>', methods=['GET'])
def get_profil(user_id):
    user = User.query.get(user_id)
    # Proveri da li ima aktivnu rezervaciju
    rez = Reservation.query.filter_by(user_id=user_id).first()
    
    rez_info = None
    if rez:
        rez_info = {
            "spot_id": rez.spot_id,
            "expire_time": rez.expire_time.isoformat() # Šaljemo vreme u string formatu
        }
        
    return jsonify({
        "name": user.name, 
        "email": user.email,
        "rezervacija": rez_info
    })

@app.route('/odrezervisi', methods=['POST'])
def odrezervisi():
    data = request.get_json()
    user_id = data.get('user_id')
    spot_id = data.get('spot_id')
    
    # Provera da li je to bas taj korisnik
    rez = Reservation.query.filter_by(user_id=user_id, spot_id=spot_id).first()
    if rez:
        mesto = ParkingSpot.query.get(spot_id)
        mesto.status = 'slobodno'
        db.session.delete(rez)
        db.session.commit()
        return jsonify({"status": "success"})
    return jsonify({"status": "error", "poruka": "Nemaš pravo na ovo!"}), 403

import os

if __name__ == '__main__':
    app.run(
        host='0.0.0.0',
        port=int(os.environ.get('PORT', 8000))
    )