from flask import Flask, jsonify

app = Flask(__name__)

@app.get("/")
def home():
    return jsonify({
        "service": "user-service",
        "status": "running"
    })

@app.get("/health")
def health():
    return jsonify({
        "service": "user-service",
        "status": "healthy"
    })

@app.get("/users")
def users():
    return jsonify([
        {"id": 1, "name": "Mani"},
        {"id": 2, "name": "DevOps User"}
    ])

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8001)
