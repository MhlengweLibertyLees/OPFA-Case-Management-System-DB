-- ============================
-- 0) Create and connect to DB
-- ============================
-- Run this on your Postgres instance (requires privileges)
CREATE DATABASE OPFA_CaseManagement
    WITH OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TEMPLATE = template0;

-- In psql, then connect:
-- \c OPFA_CaseManagement

-- Optional: create app schema
CREATE SCHEMA IF NOT EXISTS opfa AUTHORIZATION postgres;
SET search_path TO opfa, public;

-- ============================
-- 1) Reference tables
-- ============================
CREATE TABLE opfa.Ref_Status (
    StatusCode VARCHAR(30) PRIMARY KEY, -- e.g., NEW, IN_REVIEW, DETERMINED, CLOSED
    Description VARCHAR(150) NOT NULL,
    IsFinal BOOLEAN DEFAULT FALSE
);

CREATE TABLE opfa.Ref_Category (
    CategoryCode VARCHAR(30) PRIMARY KEY, -- e.g., MALADMIN, NONPAYMENT, UNDERPAYMENT
    Description VARCHAR(150) NOT NULL
);

CREATE TABLE opfa.Ref_Outcome (
    OutcomeCode VARCHAR(30) PRIMARY KEY, -- e.g., UPHELD, DISMISSED, PARTIAL
    Description VARCHAR(150) NOT NULL
);

-- ============================
-- 2) Stakeholders
-- ============================
CREATE TABLE opfa.Complainant (
    ComplainantID BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    FullName VARCHAR(150) NOT NULL,
    NationalID VARCHAR(20) UNIQUE,
    DateOfBirth DATE,
    Email VARCHAR(150),
    Phone VARCHAR(30),
    AddressLine1 VARCHAR(200),
    AddressLine2 VARCHAR(200),
    City VARCHAR(100),
    Province VARCHAR(100),
    PostalCode VARCHAR(10),
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE opfa.Fund (
    FundID BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    FundName VARCHAR(200) NOT NULL,
    RegistrationNumber VARCHAR(50) UNIQUE NOT NULL,
    ContactEmail VARCHAR(150),
    ContactPhone VARCHAR(30),
    AddressLine1 VARCHAR(200),
    AddressLine2 VARCHAR(200),
    City VARCHAR(100),
    Province VARCHAR(100),
    PostalCode VARCHAR(10),
    IsActive BOOLEAN DEFAULT TRUE,
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE opfa.Employer (
    EmployerID BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    EmployerName VARCHAR(200) NOT NULL,
    RegistrationNumber VARCHAR(50),
    Sector VARCHAR(100),
    ContactEmail VARCHAR(150),
    ContactPhone VARCHAR(30),
    AddressLine1 VARCHAR(200),
    AddressLine2 VARCHAR(200),
    City VARCHAR(100),
    Province VARCHAR(100),
    PostalCode VARCHAR(10),
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================
-- 3) Core cases
-- ============================
CREATE TABLE opfa.Complaint (
    ComplaintID BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    CaseNumber VARCHAR(30) UNIQUE NOT NULL, -- e.g., OPFA-2025-000123
    ComplainantID BIGINT NOT NULL,
    FundID BIGINT,
    EmployerID BIGINT,
    CategoryCode VARCHAR(30) NOT NULL,
    StatusCode VARCHAR(30) NOT NULL DEFAULT 'NEW',
    DateSubmitted DATE NOT NULL,
    Summary VARCHAR(1000),
    Details TEXT,
    PreferredOutcome VARCHAR(500),
    IsSensitive BOOLEAN DEFAULT FALSE,
    SLA_DueDate DATE, -- calculated based on intake rules
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_comp_complainant FOREIGN KEY (ComplainantID) REFERENCES opfa.Complainant(ComplainantID),
    CONSTRAINT fk_comp_fund FOREIGN KEY (FundID) REFERENCES opfa.Fund(FundID),
    CONSTRAINT fk_comp_employer FOREIGN KEY (EmployerID) REFERENCES opfa.Employer(EmployerID),
    CONSTRAINT fk_comp_cat FOREIGN KEY (CategoryCode) REFERENCES opfa.Ref_Category(CategoryCode),
    CONSTRAINT fk_comp_status FOREIGN KEY (StatusCode) REFERENCES opfa.Ref_Status(StatusCode)
);

CREATE TABLE opfa.Determination (
    DeterminationID BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    ComplaintID BIGINT UNIQUE NOT NULL,
    OutcomeCode VARCHAR(30) NOT NULL,
    DateIssued DATE NOT NULL,
    Summary VARCHAR(1000),
    FullText TEXT,
    DocumentURL VARCHAR(500), -- storage link
    Published BOOLEAN DEFAULT FALSE,
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_det_comp FOREIGN KEY (ComplaintID) REFERENCES opfa.Complaint(ComplaintID),
    CONSTRAINT fk_det_outcome FOREIGN KEY (OutcomeCode) REFERENCES opfa.Ref_Outcome(OutcomeCode)
);

-- ============================
-- 4) Internal operations
-- ============================
CREATE TABLE opfa.Staff (
    StaffID BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    FullName VARCHAR(150) NOT NULL,
    Email VARCHAR(150) UNIQUE NOT NULL,
    Phone VARCHAR(30),
    Department VARCHAR(100), -- e.g., Case Management, Legal
    Active BOOLEAN DEFAULT TRUE,
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE opfa.Assignment (
    AssignmentID BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    ComplaintID BIGINT NOT NULL,
    StaffID BIGINT NOT NULL,
    AssignedRole VARCHAR(50) NOT NULL, -- e.g., CaseOfficer, Adjudicator
    AssignedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UnassignedAt TIMESTAMP,
    IsPrimary BOOLEAN DEFAULT TRUE,
    CONSTRAINT fk_asg_comp FOREIGN KEY (ComplaintID) REFERENCES opfa.Complaint(ComplaintID),
    CONSTRAINT fk_asg_staff FOREIGN KEY (StaffID) REFERENCES opfa.Staff(StaffID)
);

CREATE TABLE opfa.ActionLog (
    ActionID BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    ComplaintID BIGINT NOT NULL,
    ActorType VARCHAR(20) NOT NULL, -- Staff/Complainant/Fund/Employer/System
    ActorID BIGINT, -- optional reference id
    ActionType VARCHAR(50) NOT NULL, -- e.g., STATUS_CHANGE, NOTE, DOCUMENT_ADDED
    ActionNote VARCHAR(1000),
    FromStatus VARCHAR(30),
    ToStatus VARCHAR(30),
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_act_comp FOREIGN KEY (ComplaintID) REFERENCES opfa.Complaint(ComplaintID)
);

CREATE TABLE opfa.Document (
    DocumentID BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    ComplaintID BIGINT,
    OwnerType VARCHAR(20) NOT NULL, -- Staff/Complainant/Fund/Employer
    OwnerID BIGINT,
    DocType VARCHAR(50) NOT NULL, -- e.g., Evidence, Correspondence, Determination
    FileName VARCHAR(255) NOT NULL,
    FileURL VARCHAR(500) NOT NULL,
    MimeType VARCHAR(100),
    UploadedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_doc_comp FOREIGN KEY (ComplaintID) REFERENCES opfa.Complaint(ComplaintID)
);

-- ============================
-- 5) Unclaimed benefits
-- ============================
CREATE TABLE opfa.UnclaimedBenefit (
    BenefitID BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    FundID BIGINT NOT NULL,
    MemberFullName VARCHAR(150) NOT NULL,
    NationalID VARCHAR(20),
    PolicyNumber VARCHAR(50),
    Amount DECIMAL(14,2) NOT NULL,
    StatusCode VARCHAR(30) NOT NULL DEFAULT 'NEW', -- e.g., NEW, MATCHED, PAID, CLOSED
    Notes VARCHAR(1000),
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ben_fund FOREIGN KEY (FundID) REFERENCES opfa.Fund(FundID),
    CONSTRAINT fk_ben_status FOREIGN KEY (StatusCode) REFERENCES opfa.Ref_Status(StatusCode)
);

-- ============================
-- 6) Web users and RBAC
-- ============================
CREATE TABLE opfa.Role (
    RoleID BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    RoleName VARCHAR(50) UNIQUE NOT NULL -- Admin, CaseOfficer, Adjudicator, Public
);

CREATE TABLE opfa.Permission (
    PermissionID BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    PermissionKey VARCHAR(100) UNIQUE NOT NULL, -- e.g., complaint.create, complaint.update, determination.publish
    Description VARCHAR(200)
);

CREATE TABLE opfa.RolePermission (
    RoleID BIGINT NOT NULL,
    PermissionID BIGINT NOT NULL,
    PRIMARY KEY (RoleID, PermissionID),
    CONSTRAINT fk_rp_role FOREIGN KEY (RoleID) REFERENCES opfa.Role(RoleID),
    CONSTRAINT fk_rp_perm FOREIGN KEY (PermissionID) REFERENCES opfa.Permission(PermissionID)
);

CREATE TABLE opfa.AppUser (
    UserID BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    Username VARCHAR(100) UNIQUE NOT NULL,
    PasswordHash VARCHAR(255) NOT NULL,
    Email VARCHAR(150) UNIQUE NOT NULL,
    RoleID BIGINT NOT NULL,
    StaffID BIGINT, -- link if internal staff
    ComplainantID BIGINT, -- link if complainant has a portal account
    IsActive BOOLEAN DEFAULT TRUE,
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    LastLoginAt TIMESTAMP,
    CONSTRAINT fk_user_role FOREIGN KEY (RoleID) REFERENCES opfa.Role(RoleID),
    CONSTRAINT fk_user_staff FOREIGN KEY (StaffID) REFERENCES opfa.Staff(StaffID),
    CONSTRAINT fk_user_comp FOREIGN KEY (ComplainantID) REFERENCES opfa.Complainant(ComplainantID)
);

-- ============================
-- 7) Audit & notifications
-- ============================
CREATE TABLE opfa.AuditTrail (
    AuditID BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    EntityName VARCHAR(100) NOT NULL, -- e.g., Complaint, Determination
    EntityID BIGINT NOT NULL,
    Action VARCHAR(20) NOT NULL, -- CREATE/UPDATE/DELETE
    ChangedByUserID BIGINT,
    ChangesJSON TEXT, -- { "field":"old->new", ... }
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_audit_user FOREIGN KEY (ChangedByUserID) REFERENCES opfa.AppUser(UserID)
);

CREATE TABLE opfa.Notification (
    NotificationID BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    RecipientType VARCHAR(20) NOT NULL, -- Complainant/Fund/Employer/Staff
    RecipientID BIGINT NOT NULL,
    Channel VARCHAR(20) NOT NULL, -- Email/SMS
    Subject VARCHAR(200),
    Message TEXT,
    Status VARCHAR(20) DEFAULT 'QUEUED', -- QUEUED/SENT/FAILED
    RelatedComplaintID BIGINT,
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    SentAt TIMESTAMP,
    CONSTRAINT fk_notif_comp FOREIGN KEY (RelatedComplaintID) REFERENCES opfa.Complaint(ComplaintID)
);

-- ============================
-- 8) Indexes for performance
-- ============================
CREATE INDEX idx_complaint_status ON opfa.Complaint(StatusCode);
CREATE INDEX idx_complaint_sla ON opfa.Complaint(SLA_DueDate);
CREATE INDEX idx_det_date ON opfa.Determination(DateIssued);
CREATE INDEX idx_unclaimed_nid ON opfa.UnclaimedBenefit(NationalID);
CREATE INDEX idx_doc_comp ON opfa.Document(ComplaintID);
CREATE INDEX idx_action_comp ON opfa.ActionLog(ComplaintID, CreatedAt);

-- ============================
-- 9) Triggers for timestamps & auditing
-- ============================
-- Update UpdatedAt on Complaint and UnclaimedBenefit
CREATE OR REPLACE FUNCTION opfa.touch_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.UpdatedAt := CURRENT_TIMESTAMP;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_complaint_touch
BEFORE UPDATE ON opfa.Complaint
FOR EACH ROW EXECUTE FUNCTION opfa.touch_updated_at();

CREATE TRIGGER trg_unclaimed_touch
BEFORE UPDATE ON opfa.UnclaimedBenefit
FOR EACH ROW EXECUTE FUNCTION opfa.touch_updated_at();

-- Minimal audit trigger example for Complaint
CREATE OR REPLACE FUNCTION opfa.audit_complaint() RETURNS TRIGGER AS $$
DECLARE
  diff JSONB;
BEGIN
  diff := jsonb_build_object(
    'StatusCode', to_jsonb(CONCAT(OLD.StatusCode, '->', NEW.StatusCode)),
    'Summary', CASE WHEN OLD.Summary IS DISTINCT FROM NEW.Summary
      THEN to_jsonb(CONCAT('[changed]')) ELSE to_jsonb(NULL) END
  );
  INSERT INTO opfa.AuditTrail(EntityName, EntityID, Action, ChangedByUserID, ChangesJSON)
  VALUES ('Complaint', NEW.ComplaintID, 'UPDATE', NULL, diff::text);
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_complaint_audit
AFTER UPDATE ON opfa.Complaint
FOR EACH ROW EXECUTE FUNCTION opfa.audit_complaint();

-- ============================
-- 10) Seed data (reference + roles/permissions)
-- ============================
INSERT INTO opfa.Ref_Status(StatusCode, Description, IsFinal) VALUES
  ('NEW','New complaint captured', FALSE),
  ('IN_REVIEW','Under investigation', FALSE),
  ('AWAITING_INFO','Waiting for additional information', FALSE),
  ('DETERMINED','Determination issued', TRUE),
  ('CLOSED','Case closed', TRUE);

INSERT INTO opfa.Ref_Category(CategoryCode, Description) VALUES
  ('MALADMIN','Maladministration'),
  ('NONPAYMENT','Non-payment of benefit'),
  ('UNDERPAYMENT','Underpayment of benefit'),
  ('DELAY','Delay in payment'),
  ('MISSTATEMENT','Incorrect benefit statement');

INSERT INTO opfa.Ref_Outcome(OutcomeCode, Description) VALUES
  ('UPHELD','Complaint upheld'),
  ('DISMISSED','Complaint dismissed'),
  ('PARTIAL','Partially upheld');

INSERT INTO opfa.Role(RoleName) VALUES
  ('Admin'), ('CaseOfficer'), ('Adjudicator'), ('Public');

INSERT INTO opfa.Permission(PermissionKey, Description) VALUES
  ('complaint.create','Create complaint'),
  ('complaint.update','Update complaint'),
  ('complaint.assign','Assign staff to complaint'),
  ('complaint.status','Change complaint status'),
  ('document.upload','Upload case documents'),
  ('determination.create','Create determination'),
  ('determination.publish','Publish determination'),
  ('unclaimed.search','Search unclaimed benefits'),
  ('unclaimed.manage','Manage unclaimed benefits'),
  ('admin.users','Manage users and roles');

-- Map permissions to roles (examples)
INSERT INTO opfa.RolePermission(RoleID, PermissionID)
SELECT r.RoleID, p.PermissionID
FROM opfa.Role r
JOIN opfa.Permission p ON p.PermissionKey IN (
  CASE WHEN r.RoleName = 'Admin' THEN
    'complaint.create','complaint.update','complaint.assign','complaint.status',
    'document.upload','determination.create','determination.publish',
    'unclaimed.search','unclaimed.manage','admin.users'
  WHEN r.RoleName = 'CaseOfficer' THEN
    'complaint.create','complaint.update','complaint.assign','complaint.status','document.upload','unclaimed.search'
  WHEN r.RoleName = 'Adjudicator' THEN
    'determination.create','determination.publish','complaint.status','unclaimed.search'
  WHEN r.RoleName = 'Public' THEN
    'complaint.create','document.upload','unclaimed.search'
  END
)
WHERE (r.RoleName IN ('Admin','CaseOfficer','Adjudicator','Public'));

-- Example staff + user
INSERT INTO opfa.Staff(FullName, Email, Department) VALUES
  ('Case Officer One', 'officer1@opfa.test', 'Case Management'),
  ('Adjudicator One', 'adj1@opfa.test', 'Legal');

-- Link role names to ids
WITH roles AS (
  SELECT RoleID, RoleName FROM opfa.Role
),
staff AS (
  SELECT StaffID, Email FROM opfa.Staff
)
INSERT INTO opfa.AppUser(Username, PasswordHash, Email, RoleID, StaffID, IsActive)
SELECT 'officer1', '$2y$12$samplehashforinterview', 'officer1@opfa.test',
       (SELECT RoleID FROM roles WHERE RoleName='CaseOfficer'),
       (SELECT StaffID FROM staff WHERE Email='officer1@opfa.test'),
       TRUE;

-- ============================
-- 11) Useful views for reporting
-- ============================
CREATE OR REPLACE VIEW opfa.v_sla_breaches AS
SELECT c.CaseNumber, c.StatusCode, c.SLA_DueDate, c.UpdatedAt
FROM opfa.Complaint c
WHERE c.StatusCode IN ('NEW','IN_REVIEW','AWAITING_INFO')
  AND c.SLA_DueDate IS NOT NULL
  AND c.SLA_DueDate < CURRENT_DATE;

CREATE OR REPLACE VIEW opfa.v_outcomes_summary AS
SELECT d.OutcomeCode, COUNT(*) AS Total
FROM opfa.Determination d
GROUP BY d.OutcomeCode;


