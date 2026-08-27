import os
import json
import time
import logging
from kafka import KafkaProducer
from prometheus_client import Counter, start_http_server

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

KAFKA_BOOTSTRAP_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka-cluster.kafka.svc:9092").split(",")
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "telemetry-events")

EVENTS_PRODUCED = Counter("kafka_events_produced_total", "Total Kafka Telemetry Events Produced", ["topic"])

def create_producer():
    try:
        producer = KafkaProducer(
            bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            retries=5,
            acks='all'
        )
        logging.info(f"Connected to Kafka Bootstrap Servers: {KAFKA_BOOTSTRAP_SERVERS}")
        return producer
    except Exception as e:
        logging.error(f"Kafka Connection Failed: {e}")
        return None

def publish_event(producer, payload):
    if producer:
        producer.send(KAFKA_TOPIC, payload)
        producer.flush()
        EVENTS_PRODUCED.labels(topic=KAFKA_TOPIC).inc()
        logging.info(f"Published Event to Topic [{KAFKA_TOPIC}]: {payload['event_id']}")

if __name__ == "__main__":
    start_http_server(9090)
    logging.info("Prometheus Metrics Exporter running on port 9090")
    producer = create_producer()
    count = 0
    while True:
        count += 1
        event = {
            "event_id": f"evt-{count}",
            "timestamp": time.time(),
            "status": "PROCESSED",
            "source": "devops-telemetry-engine"
        }
        publish_event(producer, event)
        time.sleep(2)
