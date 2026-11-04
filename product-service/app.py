from flask import Flask, jsonify

app = Flask(__name__)

@app.get("/")
def home():
    return jsonify({
        "service": "product-service",
        "status": "running"
    })

@app.get("/health")
def health():
    return jsonify({
        "service": "product-service",
        "status": "healthy"
    })

@app.get("/products")
def products():
    return jsonify([
        {"id": 1, "name": "Laptop"},
        {"id": 2, "name": "Keyboard"}
    ])

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8002)
