from flask import Flask, request, jsonify, send_from_directory
from flask_sqlalchemy import SQLAlchemy
from flask_bcrypt import Bcrypt
from dotenv import load_dotenv
import os
import subprocess
import jwt
import datetime
from functools import wraps
from mutagen.id3 import ID3, ID3NoHeaderError, UrlFrame
from mutagen.id3 import APIC
import base64

# Load environment variables from .env file
load_dotenv()

app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'mysecret')
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///users.db'
db = SQLAlchemy(app)
bcrypt = Bcrypt(app)

# Define the path to the 'image' folder
UPLOAD_FOLDER = 'image/'
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# Define the path to the 'database' folder
DATABASE_FOLDER = 'database/'
app.config['DATABASE_FOLDER'] = DATABASE_FOLDER

# Ensure the image folder exists
if not os.path.exists(app.config['UPLOAD_FOLDER']):
    os.makedirs(app.config['UPLOAD_FOLDER'])

# Path to the python installation
path = os.path.join("/usr", 'local', 'bin', 'python3')

# User model
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(150), unique=True, nullable=False)
    password = db.Column(db.String(150), nullable=False)

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('x-access-token')
        if not token:
            return jsonify({'message': 'Token is missing!'}), 403
        try:
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=["HS256"])
            current_user = User.query.filter_by(id=data['user_id']).first()
        except:
            return jsonify({'message': 'Token is invalid!'}), 403
        return f(current_user, *args, **kwargs)
    return decorated

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    if User.query.filter_by(username=username).first():
        return jsonify({"message": "User already exists"}), 400

    hashed_password = bcrypt.generate_password_hash(password).decode('utf-8')
    user = User(username=username, password=hashed_password)
    db.session.add(user)
    db.session.commit()

    # Create a folder for the user
    user_folder = os.path.join(app.config['DATABASE_FOLDER'], username)
    if not os.path.exists(user_folder):
        os.makedirs(user_folder)

    return jsonify({"message": "User created successfully"}), 201

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    user = User.query.filter_by(username=username).first()

    if user and bcrypt.check_password_hash(user.password, password):
        token = jwt.encode({
            'user_id': user.id,
            'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=24)
        }, app.config['SECRET_KEY'], algorithm="HS256")
        return jsonify({'token': token}), 200
    else:
        return jsonify({"message": "Invalid credentials"}), 401

@app.route('/upload', methods=['POST'])
@token_required
def upload(current_user):
    file = request.files.get('file')
    video_link = request.form.get('video_link')
    title = request.form.get('title')
    artist = request.form.get('artist')
    genre = request.form.get('genre')
    
    if file:
        filename = file.filename
        
        file_path = os.path.join('image/', filename)
        file.save(file_path)
        
        result = subprocess.run([
            path, "main.py",
            video_link, title, artist, genre, current_user.username
        ], capture_output=True, text=True)

        return jsonify({"stdout": "Success!", "stderr": result.stderr}), 200

    return jsonify({"message": "File not provided"}), 400

@app.route('/delete_song', methods=['DELETE'])
@token_required
def delete_song(current_user):
    # Get the filename from the request
    data = request.get_json()
    filename = data.get('filename')

    if not filename:
        return jsonify({"message": "Filename is required"}), 400

    # Construct the file path
    user_folder = os.path.join(app.config['DATABASE_FOLDER'], current_user.username)
    file_path = os.path.join(user_folder, filename)

    # Check if the file exists
    if not os.path.exists(file_path):
        return jsonify({"message": "File not found"}), 404

    try:
        os.remove(file_path)
        return jsonify({"message": "File deleted successfully"}), 200
    except Exception as e:
        return jsonify({"message": f"Error deleting file: {str(e)}"}), 500

@app.route('/list_songs', methods=['GET'])
@token_required
def list_songs(current_user):
    user_folder = os.path.join(app.config['DATABASE_FOLDER'], current_user.username)
    
    if not os.path.exists(user_folder):
        return jsonify({"message": "User folder not found"}), 404
    
    songs = []
    for filename in os.listdir(user_folder):
        if filename.endswith('.mp3'):
            file_path = os.path.join(user_folder, filename)
            try:
                audio = ID3(file_path)
                metadata = {
                    'title': audio.get('TIT2', 'Unknown Title').text[0] if audio.get('TIT2') else 'Unknown Title',
                    'artist': audio.get('TPE1', 'Unknown Artist').text[0] if audio.get('TPE1') else 'Unknown Artist',
                    'genre': audio.get('TCON', 'Unknown Genre').text[0] if audio.get('TCON') else 'Unknown Genre'
                }
                # Extract album art
                cover_art = None
                for tag in audio.values():
                    if isinstance(tag, APIC):
                        cover_art = tag.data
                        break
                # Convert cover art to base64
                cover_art_base64 = base64.b64encode(cover_art).decode('utf-8') if cover_art else None
                
            except ID3NoHeaderError:
                metadata = {
                    'title': 'Unknown Title',
                    'artist': 'Unknown Artist',
                    'genre': 'Unknown Genre'
                }
                cover_art_base64 = None
            
            songs.append({
                'filename': filename,
                'metadata': metadata,
                'cover_art': cover_art_base64
            })
    
    return jsonify({"songs": songs}), 200

@app.route('/get_song/<filename>', methods=['GET'])
@token_required
def get_song(current_user, filename):
    user_folder = os.path.join(app.config['DATABASE_FOLDER'], current_user.username)
    
    if not os.path.exists(user_folder):
        return jsonify({"message": "User folder not found"}), 404
    
    file_path = os.path.join(user_folder, filename)
    
    if not os.path.exists(file_path):
        return jsonify({"message": "File not found"}), 404
    
    return send_from_directory(user_folder, filename)
    
@app.route('/logout', methods=['POST'])
@token_required
def logout(current_user):
    # JWT does not support logout by default. 
    # Implementing token blacklisting is one way to handle this.
    return jsonify({"message": "Logout successful"}), 200

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(host='0.0.0.0', port=5000)
