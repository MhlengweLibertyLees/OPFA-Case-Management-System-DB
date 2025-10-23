# OPFA-Case-Management-System-DB
A database and web application design inspired by the **Office of the Pension Funds Adjudicator (OPFA)


# OPFA Case Management System

A database and web application design inspired by the **Office of the Pension Funds Adjudicator (OPFA)**.  
This project demonstrates how ICT can support statutory bodies in handling pension fund complaints, determinations, and unclaimed benefits in a secure, compliant, and scalable way.

---

## 📌 Project Overview
The system is designed to:
- Capture and manage **complaints** from pension fund members.
- Track **funds, employers, and complainants** involved in disputes.
- Record **determinations** issued by adjudicators.
- Manage **unclaimed benefits** for transparency and accessibility.
- Provide **audit trails, notifications, and SLA tracking**.
- Enforce **POPIA-compliant security** with role-based access control (RBAC).

---

## 🗄️ Database Schema
Key entities include:
- **Complainant** – individuals lodging complaints.
- **Complaint** – case records with category, status, SLA, and details.
- **Fund** & **Employer** – organizations linked to complaints.
- **Determination** – adjudicator’s decision, one per complaint.
- **Staff** & **Assignment** – internal case officers and adjudicators.
- **UnclaimedBenefit** – registry of unpaid pension benefits.
- **AppUser, Role, Permission** – RBAC for secure access.
- **AuditTrail & Notification** – compliance and communication tracking.

👉 See [`schema.sql`](./schema.sql) for the full DDL script.

---

## 🌐 Web Application Features
- **Public Portal**
  - Lodge complaints online.
  - Upload supporting documents.
  - Track complaint status.
  - Search unclaimed benefits.

- **Internal Dashboard**
  - Case officer work queues.
  - SLA breach alerts.
  - Determination drafting & publishing.
  - Document and correspondence management.

- **Administration**
  - Manage users, roles, and permissions.
  - Configure reference data (statuses, categories, outcomes).
  - Generate reports (SLA breaches, outcomes, workloads).

---

## 🔒 Security & Compliance
- Role-based access control (Admin, Case Officer, Adjudicator, Public).
- POPIA-aligned handling of personal data.
- Passwords stored as secure hashes (bcrypt/argon2).
- Audit trails for all critical actions.
- Encrypted backups and retention policies.

---

## 🚀 Getting Started
1. **Create the database**
   ```sql
   CREATE DATABASE OPFA_CaseManagement;
   \c OPFA_CaseManagement;

