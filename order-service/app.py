from flask import Flask, jsonify

app = Flask(__name__)

@app.get("/")
def home():
    return jsonify({
        "service": "order-service",
        "status": "running"
    })

@app.get("/health")
def health():
    return jsonify({
        "service": "order-service",
        "status": "healthy"
    })

@app.get("/orders")
def orders():
    return jsonify([
        {"id": 101, "user_id": 1, "product_id": 1},
        {"id": 102, "user_id": 2, "product_id": 2}
    ])

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8003)
