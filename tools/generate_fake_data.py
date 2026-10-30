#!/usr/bin/env python3
"""Generate FAKE sensitive data for the lab. Never use real personal data.

Usage (CloudShell):
    pip install --user faker
    python3 tools/generate_fake_data.py
"""
import csv
import os
import random

from faker import Faker

fake = Faker()
Faker.seed(42)
random.seed(42)
os.makedirs("data", exist_ok=True)


def write(name, header, rows):
    with open(f"data/{name}", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)


# Public
write("products.csv", ["sku", "name", "price"],
      [[f"SKU-{i:04}", fake.word().title(), round(random.uniform(5, 500), 2)] for i in range(50)])

# Internal
write("staff-directory.csv", ["emp_id", "name", "work_email", "department"],
      [[f"EMP-{random.randint(100000, 999999)}", fake.name(), fake.company_email(), fake.job()]
       for _ in range(50)])

# Confidential
write("customers.csv", ["customer_id", "name", "email", "phone", "address", "date_of_birth"],
      [[f"C-{i:04}", fake.name(), fake.email(), fake.phone_number(),
        fake.address().replace("\n", ", "), fake.date_of_birth()] for i in range(200)])

# Restricted (PCI)
write("payments.csv", ["customer_id", "card_holder", "card_number", "expiry", "iban"],
      [[f"C-{i:04}", fake.name(), fake.credit_card_number(), fake.credit_card_expire(), fake.iban()]
       for i in range(200)])

# Restricted (health)
write("patients.csv", ["patient_id", "name", "ssn", "date_of_birth", "diagnosis"],
      [[f"P-{i:04}", fake.name(), fake.ssn(), fake.date_of_birth(),
        random.choice(["Diabetes", "Asthma", "Hypertension", "Migraine"])] for i in range(100)])

# Intentionally MISCLASSIFIED file: card numbers hidden in an "internal" export. Macie should find it.
write("notes-export.csv", ["ticket", "note"],
      [[f"T-{i}", f"Customer asked to update card {fake.credit_card_number()}"] for i in range(20)])

print("done")
