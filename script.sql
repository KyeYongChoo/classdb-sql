-- Kye
-- Lookup tables
CREATE TABLE Client_Type (
    client_type_name VARCHAR(100) PRIMARY KEY
);

CREATE TABLE Color (
    color_name VARCHAR(20) PRIMARY KEY
);

CREATE TABLE Device_Category (
    category_name VARCHAR(100) PRIMARY KEY
);

-- Main tables
CREATE TABLE Client (
    client_id             INT PRIMARY KEY,
    contact_details       VARCHAR(100) UNIQUE NOT NULL,
    email                 VARCHAR(100) UNIQUE NOT NULL,
    name                  VARCHAR(100) NOT NULL,
    account_creation_date DATE NOT NULL,
    address               VARCHAR(500) NOT NULL,
    client_type           VARCHAR(100) NOT NULL,
    CONSTRAINT fk_client_client_type FOREIGN KEY (client_type)
        REFERENCES Client_Type (client_type_name)
    ON UPDATE CASCADE
);

CREATE TABLE Device_Type (
    model_name             VARCHAR(100),
    manufacturer_name      VARCHAR(100),
    device_category        VARCHAR(100) NOT NULL,
    warranty_duration_days INT NOT NULL,
    PRIMARY KEY (model_name, manufacturer_name),
    CONSTRAINT fk_device_type_category FOREIGN KEY (device_category)
        REFERENCES Device_Category (category_name)
    ON UPDATE CASCADE
);

CREATE TABLE Device (
    serial_number_or_IMEI           VARCHAR(20) PRIMARY KEY,
    description                     VARCHAR(500),
    internal_storage_capacity_in_MB INT,
    color                           VARCHAR(20) NOT NULL,
    model_name                      VARCHAR(100) NOT NULL,
    manufacturer_name               VARCHAR(100) NOT NULL,
    CONSTRAINT fk_device_color FOREIGN KEY (color)
        REFERENCES Color (color_name)
    ON UPDATE CASCADE,
    CONSTRAINT fk_device_device_type FOREIGN KEY (model_name, manufacturer_name)
        REFERENCES Device_Type (model_name, manufacturer_name)
    ON UPDATE CASCADE
);

CREATE TABLE Client_Device (
    client_id                    INT,
    device_serial_number_or_IMEI VARCHAR(20),
    PRIMARY KEY (client_id, device_serial_number_or_IMEI),
    CONSTRAINT fk_client_device_client FOREIGN KEY (client_id)
        REFERENCES Client (client_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_client_device_device FOREIGN KEY (device_serial_number_or_IMEI)
        REFERENCES Device (serial_number_or_IMEI)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- Good
-- Table generation
CREATE TABLE Tax_Rate_By_Date (
    billing_date   DATE          NOT NULL,
    sales_tax_rate DECIMAL(5, 4) NOT NULL,

    CONSTRAINT PK_tax_rate_by_date
        PRIMARY KEY (billing_date),

    CONSTRAINT CK_tax_rate
        CHECK (sales_tax_rate BETWEEN 0 AND 1)
);

-- 2. CREATE TABLES
CREATE TABLE Employee (
    employee_id INTEGER NOT NULL,
    name VARCHAR(255) NOT NULL,
    PRIMARY KEY (employee_id)
);

CREATE TABLE Technician (
    employee_id INTEGER NOT NULL,
    specialization VARCHAR(50) NOT NULL,
    certification_level SMALLINT NOT NULL,
    billing_rate DECIMAL(7,2) NOT NULL,
    PRIMARY KEY (employee_id),
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id) 
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Workshop_Manager (
    employee_id INTEGER NOT NULL,
    PRIMARY KEY (employee_id),
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id) 
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Workstation (
    workstation_id INTEGER NOT NULL,
    workshop_floor SMALLINT NOT NULL,
    equipped_for VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL,
    manager_id INTEGER NOT NULL,
    PRIMARY KEY (workstation_id),
    FOREIGN KEY (manager_id) REFERENCES Workshop_Manager(employee_id) 
        ON UPDATE CASCADE
);

CREATE TABLE Service_Ticket (
    ticket_id INTEGER NOT NULL,
    client_id INTEGER NOT NULL,
    received_date_time DATETIME NOT NULL,
    problem_description TEXT NOT NULL,
    status VARCHAR(20) NOT NULL,
    estimated_repair_cost DECIMAL(10,2),
    workstation_id INTEGER,
    serial_number_or_IMEI VARCHAR(20) NOT NULL,
    PRIMARY KEY (ticket_id),
    FOREIGN KEY (workstation_id) REFERENCES Workstation(workstation_id),
    FOREIGN KEY (client_id) REFERENCES Client(client_id),
    FOREIGN KEY (serial_number_or_IMEI) REFERENCES Device(serial_number_or_IMEI)
);

CREATE TABLE Billing_Statement (
    ticket_id             INT            NOT NULL,
    billing_date          DATE           NOT NULL,
    total_labor_charges   DECIMAL(10, 2) NOT NULL,
    total_component_costs DECIMAL(10, 2) NOT NULL,
    promotional_discounts DECIMAL(10, 2) NOT NULL DEFAULT 0,

    CONSTRAINT PK_billing_statement
        PRIMARY KEY (ticket_id),

    CONSTRAINT FK_billing_ticket
        FOREIGN KEY (ticket_id)
        REFERENCES Service_Ticket(ticket_id)
        ON DELETE CASCADE,

    CONSTRAINT FK_billing_tax
        FOREIGN KEY (billing_date)
        REFERENCES Tax_Rate_By_Date(billing_date),

    CONSTRAINT CK_billing_amounts
        CHECK (
            total_labor_charges >= 0
            AND total_component_costs >= 0
            AND promotional_discounts >= 0
            AND promotional_discounts <=
                total_labor_charges + total_component_costs
        )
);

CREATE TABLE Payment (
    payment_id  INT            NOT NULL,
    ticket_id   INT            NOT NULL,
    amount_paid DECIMAL(10, 2) NOT NULL,

    CONSTRAINT PK_payment
        PRIMARY KEY (payment_id),

    CONSTRAINT FK_payment_billing
        FOREIGN KEY (ticket_id)
        REFERENCES Billing_Statement(ticket_id),

    CONSTRAINT UQ_payment_ticket
        UNIQUE (ticket_id),

    CONSTRAINT CK_payment_amount
        CHECK (amount_paid > 0)
);

CREATE TABLE Warranty_Claim (
    claim_id        INT PRIMARY KEY,
    ticket_id       INT           NOT NULL,     -- the billing statement referenced
    submission_date DATE          NOT NULL,
    description     VARCHAR(500)  NOT NULL,
    review_status   VARCHAR(15)   NOT NULL DEFAULT 'Under Review',
    approved_remedy VARCHAR(200)  NULL,
    refund_value    DECIMAL(10,2) NULL,         -- payout requested by the customer

    CONSTRAINT FK_claim_billing
        FOREIGN KEY (ticket_id)
        REFERENCES Billing_Statement(ticket_id),

    CONSTRAINT CK_claim_status
        CHECK (
            review_status IN (
                'Under Review',
                'Approved',
                'Rejected'
            )
        ),

    CONSTRAINT CK_claim_refund
        CHECK (refund_value >= 0),

    CONSTRAINT CK_claim_remedy
        CHECK (
            approved_remedy IS NULL
            OR review_status = 'Approved'
        )
);

CREATE TABLE Diagnostic_Assessment (
    diagnostic_id INTEGER NOT NULL,
    error_code INTEGER NOT NULL,
    liquid_damage_status VARCHAR(255) NOT NULL,
    battery_health_percentage DECIMAL(5,2) NOT NULL,
    recommendation VARCHAR(255) NOT NULL,
    date_time DATETIME NOT NULL,
    ticket_id INTEGER NOT NULL,
    employee_id INTEGER NOT NULL,
    PRIMARY KEY (diagnostic_id),
    FOREIGN KEY (ticket_id) REFERENCES Service_Ticket(ticket_id) 
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (employee_id) REFERENCES Technician(employee_id) 
        ON UPDATE CASCADE
);

CREATE TABLE Repair_Procedure (
    procedure_id INTEGER NOT NULL,
    ticket_id INTEGER NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(30) NOT NULL,
    PRIMARY KEY (procedure_id),
    FOREIGN KEY (ticket_id) REFERENCES Service_Ticket(ticket_id) 
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Work_Session (
    procedure_id INTEGER NOT NULL,
    employee_id INTEGER NOT NULL,
    start_time DATETIME NOT NULL,
    end_time DATETIME,
    billable_hours DECIMAL(4,2),
    PRIMARY KEY (procedure_id, employee_id, start_time),
    FOREIGN KEY (procedure_id) REFERENCES Repair_Procedure(procedure_id) 
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (employee_id) REFERENCES Technician(employee_id)
        ON UPDATE CASCADE,
    CONSTRAINT CK_work_session_times
        CHECK (end_time IS NULL OR end_time > start_time)
);

-- 1. Inventory Manager
CREATE TABLE Inventory_Manager (
    employee_id INT NOT NULL,

    CONSTRAINT PK_Inventory_Manager
        PRIMARY KEY (employee_id),

    CONSTRAINT FK_Inventory_Manager_Employee
        FOREIGN KEY (employee_id)
        REFERENCES Employee(employee_id)
);


-- 2. Part
CREATE TABLE Part (
    part_code              VARCHAR(30)    NOT NULL,
    description            VARCHAR(200)   NOT NULL,
    category               VARCHAR(50)    NOT NULL,
    standard_selling_price DECIMAL(10, 2) NOT NULL,
    quantity_on_hand       INT            NOT NULL,
    reorder_threshold      INT            NOT NULL,

    CONSTRAINT PK_Part
        PRIMARY KEY (part_code),

    CONSTRAINT CK_Part_Amounts
        CHECK (
            standard_selling_price >= 0
            AND quantity_on_hand >= 0
            AND reorder_threshold > 0
        )
);


-- 3. Locked Price
CREATE TABLE Locked_Price (
    part_code         VARCHAR(30)    NOT NULL,
    date_time         DATETIME2(0)   NOT NULL,
    locked_unit_price DECIMAL(10, 2) NOT NULL,

    CONSTRAINT PK_Locked_Price
        PRIMARY KEY (part_code, date_time),

    CONSTRAINT FK_Locked_Price_Part
        FOREIGN KEY (part_code)
        REFERENCES Part(part_code),

    CONSTRAINT CK_Locked_Price
        CHECK (locked_unit_price >= 0)
);


-- 4. Part Usage
CREATE TABLE Part_Usage (
    usage_no      INT          NOT NULL,
    part_code     VARCHAR(30)  NOT NULL,
    procedure_id  INT          NOT NULL,
    date_time     DATETIME2(0) NOT NULL,
    quantity_used INT          NOT NULL,

    CONSTRAINT PK_Part_Usage
        PRIMARY KEY (usage_no, part_code, procedure_id),

    CONSTRAINT FK_Part_Usage_Procedure
        FOREIGN KEY (procedure_id)
        REFERENCES Repair_Procedure(procedure_id),

    CONSTRAINT FK_Part_Usage_Locked_Price
        FOREIGN KEY (part_code, date_time)
        REFERENCES Locked_Price(part_code, date_time),

    CONSTRAINT CK_Part_Usage_Quantity
        CHECK (quantity_used > 0)
);


-- 5. Supplier
CREATE TABLE Supplier (
    supplier_id   INT          NOT NULL,
    name          VARCHAR(100) NOT NULL,
    email         VARCHAR(100) NOT NULL,
    payment_terms VARCHAR(50)  NOT NULL,

    CONSTRAINT PK_Supplier
        PRIMARY KEY (supplier_id)
);


-- 6. Supplier Phone
CREATE TABLE Supplier_Phone (
    supplier_id   INT         NOT NULL,
    phone_numbers VARCHAR(25) NOT NULL,

    CONSTRAINT PK_Supplier_Phone
        PRIMARY KEY (supplier_id, phone_numbers),

    CONSTRAINT FK_Supplier_Phone_Supplier
        FOREIGN KEY (supplier_id)
        REFERENCES Supplier(supplier_id)
);


-- 7. Purchase Order
CREATE TABLE Purchase_Order (
    order_id               INT            NOT NULL,
    order_date             DATE           NOT NULL,
    expected_delivery_date DATE           NOT NULL,
    total_cost             DECIMAL(12, 2) NOT NULL,
    status                 VARCHAR(30)    NOT NULL,
    supplier_id            INT            NOT NULL,

    CONSTRAINT PK_Purchase_Order
        PRIMARY KEY (order_id),

    CONSTRAINT FK_Purchase_Order_Supplier
        FOREIGN KEY (supplier_id)
        REFERENCES Supplier(supplier_id),

    CONSTRAINT CK_Purchase_Order_Cost
        CHECK (total_cost >= 0),

    CONSTRAINT CK_Purchase_Order_Dates
        CHECK (expected_delivery_date >= order_date),

    CONSTRAINT CK_Purchase_Order_Status
        CHECK (status IN ('Pending', 'Shipped', 'Received', 'Cancelled'))
);


-- 8. Restock Request
CREATE TABLE Restock_Request (
    request_id           INT         NOT NULL,
    inventory_manager_id INT         NOT NULL,
    request_date         DATE        NOT NULL,
    quantity             INT         NOT NULL,
    order_id             INT         NOT NULL,
    part_code            VARCHAR(30) NOT NULL,

    CONSTRAINT PK_Restock_Request
        PRIMARY KEY (request_id),

    CONSTRAINT FK_Restock_Request_Manager
        FOREIGN KEY (inventory_manager_id)
        REFERENCES Inventory_Manager(employee_id),

    CONSTRAINT FK_Restock_Request_Order
        FOREIGN KEY (order_id)
        REFERENCES Purchase_Order(order_id),

    CONSTRAINT FK_Restock_Request_Part
        FOREIGN KEY (part_code)
        REFERENCES Part(part_code),

    CONSTRAINT CK_Restock_Request_Quantity
        CHECK (quantity > 0)
);
GO

-- Date-order rules. SQL Server has no CREATE ASSERTION and a CHECK can only
-- see its own row, so each cross-table rule is enforced by triggers on the
-- tables on both sides of it. Each CREATE TRIGGER must be alone in its batch,
-- hence the GO lines. They come before the sample data so it gets checked too.

-- A bill can't predate its ticket, and its warranty claims must stay inside
-- the 90-day window if the billing date changes.
CREATE TRIGGER trg_billing_date_order
ON Billing_Statement
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Service_Ticket t ON t.ticket_id = i.ticket_id
        WHERE i.billing_date < CAST(t.received_date_time AS DATE))
    BEGIN
        THROW 50004, 'Billing statement rejected: billing date is before the ticket was received.', 1;
    END;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Warranty_Claim w ON w.ticket_id = i.ticket_id
        WHERE w.submission_date < i.billing_date
           OR w.submission_date > DATEADD(DAY, 90, i.billing_date))
    BEGIN
        THROW 50005, 'Billing statement rejected: an existing warranty claim would fall outside the 90-day window.', 1;
    END;
END;
GO

-- 90-day store warranty: claim must be filed on/after billing date and within 90 days
CREATE TRIGGER trg_warranty_claim_window
ON Warranty_Claim
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Billing_Statement b ON b.ticket_id = i.ticket_id
        WHERE i.submission_date < b.billing_date
           OR i.submission_date > DATEADD(DAY, 90, b.billing_date))
    BEGIN
        THROW 50003, 'Warranty claim rejected: submission date is outside the 90-day store warranty period.', 1;
    END;
END;
GO

CREATE TRIGGER trg_diagnosis_after_received
ON Diagnostic_Assessment
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Service_Ticket t ON t.ticket_id = i.ticket_id
        WHERE i.date_time < t.received_date_time)
    BEGIN
        THROW 50006, 'Diagnostic assessment rejected: it is dated before the ticket was received.', 1;
    END;
END;
GO

CREATE TRIGGER trg_work_after_received
ON Work_Session
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Repair_Procedure p ON p.procedure_id = i.procedure_id
        JOIN Service_Ticket t ON t.ticket_id = p.ticket_id
        WHERE i.start_time < t.received_date_time)
    BEGIN
        THROW 50007, 'Work session rejected: it starts before the ticket was received.', 1;
    END;
END;
GO

-- Moving a procedure to another ticket must not leave its work sessions
-- starting before that ticket was received.
CREATE TRIGGER trg_procedure_ticket_change
ON Repair_Procedure
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(ticket_id) RETURN;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Service_Ticket t ON t.ticket_id = i.ticket_id
        JOIN Work_Session w ON w.procedure_id = i.procedure_id
        WHERE w.start_time < t.received_date_time)
    BEGIN
        THROW 50008, 'Repair procedure rejected: its work sessions start before the new ticket was received.', 1;
    END;
END;
GO

-- Moving a ticket's received date later must not leave its bill, diagnoses
-- or work sessions dated before it.
CREATE TRIGGER trg_ticket_received_change
ON Service_Ticket
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(received_date_time) RETURN;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE EXISTS (SELECT 1 FROM Billing_Statement b
                      WHERE b.ticket_id = i.ticket_id
                        AND b.billing_date < CAST(i.received_date_time AS DATE))
           OR EXISTS (SELECT 1 FROM Diagnostic_Assessment d
                      WHERE d.ticket_id = i.ticket_id
                        AND d.date_time < i.received_date_time)
           OR EXISTS (SELECT 1 FROM Repair_Procedure p
                      JOIN Work_Session w ON w.procedure_id = p.procedure_id
                      WHERE p.ticket_id = i.ticket_id
                        AND w.start_time < i.received_date_time))
    BEGIN
        THROW 50009, 'Service ticket rejected: its bill, diagnoses or work sessions would be dated before it was received.', 1;
    END;
END;
GO

-- Sample data for the main tables.
-- Run AFTER the schema script (which creates the tables and the original lookup rows).

INSERT INTO Client_Type (client_type_name) VALUES
    ('Corporate Client'),
    ('Regular Client');
    
INSERT INTO Color (color_name) VALUES
    ('Red'),
    ('Green'),
    ('Hot Pink'),
    ('Goofy Orange'),
    ('Black'),
    ('White'),
    ('Silver'),
    ('Blue'),
    ('Graphite'),
    ('Midnight'),
    ('Purple');
    
INSERT INTO Device_Category (category_name) VALUES
    ('Smartphone'),
    ('Tablet'),
    ('Smartwatch'),
    ('Earbuds'),
    ('Headphones');

-- Clients
INSERT INTO Client (client_id, contact_details, email, name, account_creation_date, address, client_type) VALUES
    (1001, '+1-555-0100', 'ravi.kumar@example.net', 'Ravi Kumar', '2021-11-22', '267 Harbour View Road, Brookdale 11852', 'Regular Client'),
    (1002, '+1-555-0111', 'liam.oconnor@example.com', 'Liam O''Connor', '2022-01-26', 'Apt 19D, 189 Willow Crescent, Brookdale 65340', 'Regular Client'),
    (1003, '+1-555-0158', 'arjun.patel@example.org', 'Arjun Patel', '2022-05-10', '289 Hillcrest Way, Westmere 77893', 'Regular Client'),
    (1004, '+1-555-0182', 'ethan.lim@example.com', 'Ethan Lim', '2022-06-16', 'Apt 1A, 190 Riverside Drive, Riverton 63911', 'Regular Client'),
    (1005, '+1-555-0142', 'admin@bluepeak.example.com', 'Bluepeak Consulting', '2022-07-22', 'Level 21, 143 Harbour Front Avenue, Westmere 81802', 'Corporate Client'),
    (1006, '+1-555-0152', 'isabella.costa@example.com', 'Isabella Costa', '2022-10-22', '251 Willow Crescent, Riverton 44093', 'Regular Client'),
    (1007, '+1-555-0169', 'siti.aminah@example.com', 'Siti Aminah', '2022-12-20', '232 Elm Street, Westmere 20887', 'Regular Client'),
    (1008, '+1-555-0185', 'lucas.silva@example.net', 'Lucas Silva', '2022-12-29', '251 Willow Crescent, Riverton 44093', 'Regular Client'),
    (1009, '+1-555-0123', 'noah.williams@example.net', 'Noah Williams', '2023-02-04', '158 Kingfisher Close, Westmere 72769', 'Regular Client'),
    (1010, '+1-555-0103', 'aisha.rahman@example.com', 'Aisha Rahman', '2023-02-09', 'Apt 19C, 276 Cedar Court, Lakeside 69958', 'Regular Client'),
    (1011, '+1-555-0145', 'mateo.rossi@example.org', 'Mateo Rossi', '2023-05-31', '183 Oak Lane, Fairview 51083', 'Regular Client'),
    (1012, '+1-555-0120', 'grace.okafor@example.net', 'Grace Okafor', '2023-06-18', '127 Riverside Drive, Westmere 15853', 'Regular Client'),
    (1013, '+1-555-0189', 'chloe.dubois@example.net', 'Chloe Dubois', '2023-08-09', '94 Station Road, Brookdale 18427', 'Regular Client'),
    (1014, '+1-555-0171', 'devices@crescentmedia.example.com', 'Crescent Media Group', '2023-12-19', 'Level 9, 1 Commerce Street, Fairview 47649', 'Corporate Client'),
    (1015, '+1-555-0173', 'it@northwind.example.com', 'Northwind Logistics Ltd', '2024-01-26', 'Level 5, 82 Commerce Street, Riverton 88778', 'Corporate Client'),
    (1016, '+1-555-0168', 'sofia.martinez@example.com', 'Sofia Martinez', '2024-01-30', '115 Oak Lane, Fairview 78579', 'Regular Client'),
    (1017, '+1-555-0127', 'office@harbourfinch.example.com', 'Harbour & Finch Legal LLP', '2024-03-27', 'Level 28, 188 Harbour Front Avenue, Westmere 67815', 'Corporate Client'),
    (1018, '+1-555-0114', 'ops@brightline.example.com', 'Brightline Analytics', '2024-06-05', 'Level 22, 20 Enterprise Boulevard, Fairview 83066', 'Corporate Client'),
    (1019, '+1-555-0179', 'fatima.hassan@example.org', 'Fatima Hassan', '2024-08-30', '234 Hillcrest Way, Westmere 42899', 'Regular Client'),
    (1020, '+1-555-0135', 'mei.ling.chen@example.net', 'Mei Ling Chen', '2024-11-13', 'Apt 17C, 218 Kingfisher Close, Westmere 74360', 'Regular Client'),
    (1021, '+1-555-0186', 'emma.johansson@example.org', 'Emma Johansson', '2025-04-22', 'Apt 1A, 38 Maple Avenue, Lakeside 94708', 'Regular Client'),
    (1022, '+1-555-0172', 'kenji.watanabe@example.com', 'Kenji Watanabe', '2025-05-20', '220 Hillcrest Way, Riverton 73191', 'Regular Client'),
    (1023, '+1-555-0183', 'procurement@orchidhospitality.example.com', 'Orchid Hospitality Group', '2025-08-27', 'Level 10, 90 Enterprise Boulevard, Brookdale 77316', 'Corporate Client'),
    (1024, '+1-555-0178', 'priya.nair@example.org', 'Priya Nair', '2025-09-02', 'Apt 5D, 222 Harbour View Road, Lakeside 45263', 'Regular Client'),
    (1025, '+1-555-0137', 'benjamin.lee@example.net', 'Benjamin Lee', '2025-10-12', 'Apt 4D, 244 Willow Crescent, Lakeside 69000', 'Regular Client'),
    (1026, '+1-555-0176', 'it-support@ironleaf.example.com', 'Ironleaf Engineering', '2025-12-30', 'Level 28, 26 Harbour Front Avenue, Fairview 99807', 'Corporate Client'),
    (1027, '+1-555-0134', 'admin@summitridge.example.com', 'Summit Ridge Clinic', '2026-03-19', 'Level 17, 174 Enterprise Boulevard, Riverton 62064', 'Corporate Client'),
    (1028, '+1-555-0181', 'yuki.tanaka@example.com', 'Yuki Tanaka', '2026-04-03', 'Apt 5C, 252 Oak Lane, Westmere 39219', 'Regular Client'),
    (1029, '+1-555-0116', 'omar.farouk@example.net', 'Omar Farouk', '2026-06-01', 'Apt 17C, 149 Willow Crescent, Brookdale 22894', 'Regular Client'),
    (1030, '+1-555-0112', 'hannah.schmidt@example.com', 'Hannah Schmidt', '2026-08-04', '262 Hillcrest Way, Brookdale 83116', 'Regular Client');

-- Device types 
INSERT INTO Device_Type (model_name, manufacturer_name, device_category, warranty_duration_days) VALUES
    ('iPhone 15', 'Apple', 'Smartphone', 365),
    ('iPhone 15 Pro', 'Apple', 'Smartphone', 365),
    ('iPhone 16', 'Apple', 'Smartphone', 365),
    ('Galaxy S24', 'Samsung', 'Smartphone', 730),
    ('Galaxy A55', 'Samsung', 'Smartphone', 730),
    ('Pixel 8', 'Google', 'Smartphone', 365),
    ('Pixel 9 Pro', 'Google', 'Smartphone', 365),
    ('Xiaomi 14', 'Xiaomi', 'Smartphone', 545),
    ('iPad Air (M2)', 'Apple', 'Tablet', 365),
    ('iPad (10th generation)', 'Apple', 'Tablet', 365),
    ('Galaxy Tab S9', 'Samsung', 'Tablet', 730),
    ('Apple Watch Series 9', 'Apple', 'Smartwatch', 365),
    ('Galaxy Watch6', 'Samsung', 'Smartwatch', 365),
    ('Pixel Watch 2', 'Google', 'Smartwatch', 365),
    ('AirPods Pro (2nd generation)', 'Apple', 'Earbuds', 365),
    ('Galaxy Buds2 Pro', 'Samsung', 'Earbuds', 180),
    ('WF-1000XM5', 'Sony', 'Earbuds', 365),
    ('WH-1000XM5', 'Sony', 'Headphones', 365),
    ('QuietComfort Ultra Headphones', 'Bose', 'Headphones', 365),
    ('AirPods Max', 'Apple', 'Headphones', 365);

-- Devices. Earbuds and headphones have no storage, so it is NULL.
INSERT INTO Device (serial_number_or_IMEI, description, internal_storage_capacity_in_MB, color, model_name, manufacturer_name) VALUES
    ('350159450283163', 'Bought as a gift', 524288, 'Black', 'iPhone 15', 'Apple'),
    ('351152761138753', 'Used by field sales team', 524288, 'Black', 'iPhone 15', 'Apple'),
    ('351805154382995', 'Used by field sales team', 131072, 'Black', 'iPhone 15', 'Apple'),
    ('351981524735731', 'Used by field sales team', 262144, 'Silver', 'iPhone 15', 'Apple'),
    ('355200700917039', 'Refurbished unit', 524288, 'Silver', 'iPhone 15', 'Apple'),
    ('355914833541488', 'Purchased new', 524288, 'Purple', 'iPhone 15', 'Apple'),
    ('357418288983706', 'Spare handset kept in IT inventory', 524288, 'Black', 'iPhone 15', 'Apple'),
    ('350203830040305', 'Spare handset kept in IT inventory', 131072, 'Black', 'iPhone 15 Pro', 'Apple'),
    ('350626148836156', 'Company-issued work phone', 131072, 'Red', 'iPhone 15 Pro', 'Apple'),
    ('351649415771889', 'Screen replaced under warranty', 131072, 'Graphite', 'iPhone 15 Pro', 'Apple'),
    ('353006681792230', 'Battery replaced', 131072, 'Black', 'iPhone 15 Pro', 'Apple'),
    ('357264366282904', 'Battery replaced', 524288, 'Purple', 'iPhone 15 Pro', 'Apple'),
    ('354220426283707', 'Spare handset kept in IT inventory', 524288, 'Black', 'iPhone 16', 'Apple'),
    ('355719294808536', 'Spare handset kept in IT inventory', 524288, 'Silver', 'iPhone 16', 'Apple'),
    ('357718621076179', 'Purchased new', 262144, 'Silver', 'iPhone 16', 'Apple'),
    ('353896501332799', NULL, 262144, 'Hot Pink', 'Pixel 8', 'Google'),
    ('356517883655063', 'Used by field sales team', 524288, 'Black', 'Pixel 8', 'Google'),
    ('358602145842101', 'Refurbished unit', 524288, 'Red', 'Pixel 8', 'Google'),
    ('359871988904216', 'Refurbished unit', 262144, 'Black', 'Pixel 8', 'Google'),
    ('351769585190437', 'Bought as a gift', 131072, 'Red', 'Pixel 9 Pro', 'Google'),
    ('354668631665391', NULL, 524288, 'Blue', 'Pixel 9 Pro', 'Google'),
    ('355263097658285', 'Refurbished unit', 131072, 'White', 'Galaxy A55', 'Samsung'),
    ('356352136295867', 'Spare handset kept in IT inventory', 131072, 'Green', 'Galaxy A55', 'Samsung'),
    ('357428435281441', 'Bought as a gift', 524288, 'Graphite', 'Galaxy A55', 'Samsung'),
    ('358801564644036', 'Purchased new', 131072, 'Black', 'Galaxy A55', 'Samsung'),
    ('350399551566971', NULL, 524288, 'Graphite', 'Galaxy S24', 'Samsung'),
    ('351159212363609', 'Refurbished unit', 524288, 'Graphite', 'Galaxy S24', 'Samsung'),
    ('354370108752626', NULL, 131072, 'Blue', 'Galaxy S24', 'Samsung'),
    ('355081113617956', 'Company-issued work phone', 524288, 'Silver', 'Galaxy S24', 'Samsung'),
    ('357852223841647', NULL, 524288, 'Silver', 'Galaxy S24', 'Samsung'),
    ('351671552930128', 'Bought as a gift', 262144, 'Black', 'Xiaomi 14', 'Xiaomi'),
    ('358923524013761', 'Screen replaced under warranty', 131072, 'White', 'Xiaomi 14', 'Xiaomi'),
    ('CTUFCT7XE25W', 'Used for point-of-sale at front desk', 131072, 'Black', 'iPad (10th generation)', 'Apple'),
    ('MN7QYY42PK6J', 'Bought for online classes', 131072, 'White', 'iPad (10th generation)', 'Apple'),
    ('SY6RMVCNVL5J', 'Bought for online classes', 131072, 'Graphite', 'iPad (10th generation)', 'Apple'),
    ('2T66VS648UWL', NULL, 65536, 'Blue', 'iPad Air (M2)', 'Apple'),
    ('URWT5BYLHZPE', 'Used for point-of-sale at front desk', 262144, 'Silver', 'iPad Air (M2)', 'Apple'),
    ('YFEF9VSQLW5X', NULL, 131072, 'Graphite', 'Galaxy Tab S9', 'Samsung'),
    ('4HZHJGU9B38X', 'Strap replaced', 65536, 'White', 'Apple Watch Series 9', 'Apple'),
    ('4SCS7U4SP6LY', NULL, 65536, 'Hot Pink', 'Apple Watch Series 9', 'Apple'),
    ('B7RP5JPT9JWZ', NULL, 65536, 'Blue', 'Apple Watch Series 9', 'Apple'),
    ('DJRWWQSTAULT', 'Strap replaced', 65536, 'White', 'Apple Watch Series 9', 'Apple'),
    ('K49BVQZF74KW', 'Used for fitness tracking', 65536, 'Midnight', 'Apple Watch Series 9', 'Apple'),
    ('DWSF77YGTUCF', 'Issued to warehouse supervisor', 32768, 'Black', 'Pixel Watch 2', 'Google'),
    ('L3DE7486KAUG', 'Used for fitness tracking', 32768, 'Silver', 'Pixel Watch 2', 'Google'),
    ('VCXV4QUYY2QA', 'Strap replaced', 32768, 'Blue', 'Pixel Watch 2', 'Google'),
    ('C32LGFK2XSVC', 'Issued to warehouse supervisor', 16384, 'Black', 'Galaxy Watch6', 'Samsung'),
    ('JX488XACQHTW', 'Issued to warehouse supervisor', 16384, 'Midnight', 'Galaxy Watch6', 'Samsung'),
    ('K4SB6UK2A6HG', 'Issued to warehouse supervisor', 16384, 'Red', 'Galaxy Watch6', 'Samsung'),
    ('S5GQZE4FSW5V', 'Used for fitness tracking', 16384, 'Midnight', 'Galaxy Watch6', 'Samsung'),
    ('43ARNDSLTZFS', 'Issued for video calls', NULL, 'Black', 'AirPods Pro (2nd generation)', 'Apple'),
    ('68BX9MLPENN9', 'Issued for video calls', NULL, 'Hot Pink', 'AirPods Pro (2nd generation)', 'Apple'),
    ('KKKJDCTVMJTY', NULL, NULL, 'Black', 'AirPods Pro (2nd generation)', 'Apple'),
    ('Q9PZL557ZPV6', 'Issued for video calls', NULL, 'Red', 'AirPods Pro (2nd generation)', 'Apple'),
    ('V8FW9WXZMEMS', NULL, NULL, 'Black', 'AirPods Pro (2nd generation)', 'Apple'),
    ('C9RM6NH828B9', NULL, NULL, 'Midnight', 'Galaxy Buds2 Pro', 'Samsung'),
    ('QTXNZY778VNL', 'Left earbud replaced under warranty', NULL, 'Silver', 'Galaxy Buds2 Pro', 'Samsung'),
    ('SWRXFNTMF7MQ', 'Came in a phone bundle', NULL, 'Graphite', 'Galaxy Buds2 Pro', 'Samsung'),
    ('TL7FBYEJR8KW', NULL, NULL, 'Blue', 'Galaxy Buds2 Pro', 'Samsung'),
    ('B57DC8K83HYH', 'Issued for video calls', NULL, 'Black', 'WF-1000XM5', 'Sony'),
    ('H6CY7CN8DUFL', NULL, NULL, 'Black', 'WF-1000XM5', 'Sony'),
    ('JGBT4CMQ8XXY', NULL, NULL, 'White', 'WF-1000XM5', 'Sony'),
    ('TZFNAGKXQ7PL', 'Issued for video calls', NULL, 'Blue', 'WF-1000XM5', 'Sony'),
    ('DEU5FNNABWNB', 'Used for daily commute', NULL, 'White', 'AirPods Max', 'Apple'),
    ('EJTT3AM3FZ3A', 'Issued to call-centre staff', NULL, 'Black', 'AirPods Max', 'Apple'),
    ('G278BKWJBG3F', NULL, NULL, 'Red', 'AirPods Max', 'Apple'),
    ('MVABXM7GR8L8', 'Issued to call-centre staff', NULL, 'Black', 'AirPods Max', 'Apple'),
    ('6W2YAY2YS8AZ', 'Kept in meeting room', NULL, 'Black', 'QuietComfort Ultra Headphones', 'Bose'),
    ('C9JB8ZS7NZT3', 'Used for daily commute', NULL, 'Blue', 'QuietComfort Ultra Headphones', 'Bose'),
    ('KT73GPVHS4E8', 'Kept in meeting room', NULL, 'White', 'QuietComfort Ultra Headphones', 'Bose'),
    ('UZ3A87TY9JGK', 'Ear cushions replaced', NULL, 'Silver', 'QuietComfort Ultra Headphones', 'Bose'),
    ('XQCY995DXZNS', 'Kept in meeting room', NULL, 'Blue', 'QuietComfort Ultra Headphones', 'Bose'),
    ('53QXG394KW7N', NULL, NULL, 'Midnight', 'WH-1000XM5', 'Sony'),
    ('E2CJ6BU4Z6ND', 'Ear cushions replaced', NULL, 'Black', 'WH-1000XM5', 'Sony'),
    ('Z6CNCV86G43E', 'Ear cushions replaced', NULL, 'Silver', 'WH-1000XM5', 'Sony'),
    ('861928471029481', 'Ink-blot display unit', 524288, 'Silver', 'Galaxy S24', 'Samsung'),
    ('C02K9018MD8R', 'Liquid-damaged tablet unit', 262144, 'Silver', 'iPad Air (M2)', 'Apple'),
    ('6PN019284',
    'Altitude sensor watch', 32768, 'Black', 'Pixel Watch 2', 'Google'),
    ('492018471920', 'Left earcup unit', NULL, 'Black', 'WH-1000XM5', 'Sony'),
    ('R58M30XYZ7W', 'Battery drain repair unit', 131072, 'Black', 'iPhone 15', 'Apple'), 
    ('352099118492014', 'Cracked front glass unit', 262144, 'Black', 'Pixel 8', 'Google'), 
    ('990000862471850', 'Lifted OLED watch unit', 65536, 'Black', 'Apple Watch Series 9', 'Apple'), 
    ('2948201A83B4', 'ANC earbud unit', NULL, 'White', 'AirPods Pro (2nd generation)', 'Apple'),
    ('H3XKJ94W7V', 'Static noise earbud unit', NULL, 'White', 'AirPods Pro (2nd generation)', 'Apple'),
    ('867531024680135', 'Water-damaged unit', 262144, 'Graphite', 'iPhone 15 Pro', 'Apple'), 
    ('C02F93K1MD6T', 'Crushed earcup headphones', NULL, 'Black', 'WH-1000XM5', 'Sony'), 
    ('R58N20ABC1X', 'Muffled call unit', NULL, 'Black', 'QuietComfort Ultra Headphones', 'Bose'), 
    ('356938035643809', 'Camera vibration unit', 524288, 'Black', 'Galaxy Tab S9', 'Samsung'), 
    ('DMPX81G9Q1GC', 'Ghost touch unit', 524288, 'Graphite', 'Galaxy S24', 'Samsung'), 
    ('R58K10M99YZ', 'Cracked rear sensor watch', 16384, 'Silver', 'Galaxy Watch6', 'Samsung'), 
    ('SN591028301', 'Dead left earbud', NULL, 'White', 'Galaxy Buds2 Pro', 'Samsung'), 
    ('M4NR901B1829', 'Grinding haptic motor watch', 32768, 'Blue', 'Pixel Watch 2', 'Google'), 
    ('C02G84J2Q05D', 'Speaker buzz unit', 262144, 'Blue', 'Galaxy A55', 'Samsung'),
    ('862047041289563', 'Water-damaged display unit',    262144, 'Black',    'Pixel 8',                       'Google'),
    ('PF39K7LA',        'Dropped tablet unit',           262144, 'Silver',   'iPad Air (M2)',                 'Apple'),
    ('7B8N4Y2',         'Coffee-damaged tablet unit',    262144, 'Graphite', 'Galaxy Tab S9',                 'Samsung'),
    ('PF48X90L',        'Charging port unit',            524288, 'Silver',   'iPhone 16',                     'Apple'),
    ('082910481920',    'Left yoke hinge unit',          NULL,   'Black',    'WH-1000XM5',                    'Sony'),
    ('354910284719028', 'Pogo pin tablet',               131072, 'Black',    'Galaxy Tab S9',                 'Samsung'),
    ('359018274019283', 'Back glass unit',               262144, 'Black',    'iPhone 15 Pro',                 'Apple'),
    ('5CD1298XLM',      'Swollen battery tablet',        131072, 'Silver',   'iPad Air (M2)',                 'Apple'),
    ('004928172948',    'Stylus digitizer tablet',       262144, 'Silver',   'Galaxy Tab S9',                 'Samsung'),
    ('864910293847561', 'Slow-charging phone',           262144, 'Blue',     'Galaxy S24',                    'Samsung'),
    ('492019382019',    'Headband slider headphones',    NULL,   'White',    'WH-1000XM5',                    'Sony'),
    ('NHQ8X01928',      'Crashing tablet unit',          131072, 'Graphite', 'iPad (10th generation)',        'Apple'),
    ('992019284019283', 'Digital crown watch',           65536,  'Silver',   'Apple Watch Series 9',          'Apple'),
    ('DMPZ8019KD84',    'Battery drain phone',           524288, 'Graphite', 'Pixel 9 Pro',                   'Google'),
    ('861920384719204', 'Shattered lens phone',          524288, 'Black',    'Pixel 9 Pro',                   'Google'),
    ('8H92KP3',         'Non-booting tablet unit',       262144, 'Black',    'iPad Air (M2)',                 'Apple'),
    ('990182740192834', 'Unresponsive watch display',    16384,  'Black',    'Galaxy Watch6',                 'Samsung'),
    ('294810294819',    'Oxidized earbud unit',          NULL,   'Silver',   'AirPods Pro (2nd generation)',  'Apple');

-- Device ownership (one owner per device)
INSERT INTO Client_Device (client_id, device_serial_number_or_IMEI) VALUES
    (1001, '353006681792230'),
    (1001, '355200700917039'),
    (1002, 'E2CJ6BU4Z6ND'),
    (1002, 'YFEF9VSQLW5X'),
    (1003, '2T66VS648UWL'),
    (1003, '358801564644036'),
    (1003, 'Z6CNCV86G43E'),
    (1004, '354668631665391'),
    (1004, '357428435281441'),
    (1004, 'MN7QYY42PK6J'),
    (1005, '354220426283707'),
    (1005, '356517883655063'),
    (1005, 'C32LGFK2XSVC'),
    (1005, 'DWSF77YGTUCF'),
    (1005, 'JX488XACQHTW'),
    (1005, 'K4SB6UK2A6HG'),
    (1006, '350159450283163'),
    (1006, '355914833541488'),
    (1007, '358602145842101'),
    (1008, 'DJRWWQSTAULT'),
    (1009, 'DEU5FNNABWNB'),
    (1010, '351769585190437'),
    (1010, 'K49BVQZF74KW'),
    (1011, '355263097658285'),
    (1011, '357264366282904'),
    (1011, '358923524013761'),
    (1011, 'SWRXFNTMF7MQ'),
    (1012, 'VCXV4QUYY2QA'),
    (1013, '351649415771889'),
    (1013, '357852223841647'),
    (1014, '350399551566971'),
    (1014, '356352136295867'),
    (1014, '53QXG394KW7N'),
    (1014, 'B7RP5JPT9JWZ'),
    (1014, 'C9RM6NH828B9'),
    (1014, 'KT73GPVHS4E8'),
    (1015, '351805154382995'),
    (1015, '355081113617956'),
    (1015, '357418288983706'),
    (1015, 'B57DC8K83HYH'),
    (1015, 'CTUFCT7XE25W'),
    (1016, '4HZHJGU9B38X'),
    (1017, 'MVABXM7GR8L8'),
    (1017, 'XQCY995DXZNS'),
    (1018, '43ARNDSLTZFS'),
    (1018, '68BX9MLPENN9'),
    (1018, '6W2YAY2YS8AZ'),
    (1018, 'G278BKWJBG3F'),
    (1018, 'H6CY7CN8DUFL'),
    (1018, 'JGBT4CMQ8XXY'),
    (1019, '351159212363609'),
    (1019, 'QTXNZY778VNL'),
    (1020, 'L3DE7486KAUG'),
    (1021, '354370108752626'),
    (1021, 'UZ3A87TY9JGK'),
    (1022, 'V8FW9WXZMEMS'),
    (1023, '351981524735731'),
    (1023, '355719294808536'),
    (1023, 'Q9PZL557ZPV6'),
    (1023, 'URWT5BYLHZPE'),
    (1024, 'C9JB8ZS7NZT3'),
    (1024, 'SY6RMVCNVL5J'),
    (1025, '357718621076179'),
    (1025, 'S5GQZE4FSW5V'),
    (1026, '350626148836156'),
    (1026, 'EJTT3AM3FZ3A'),
    (1026, 'KKKJDCTVMJTY'),
    (1026, 'TZFNAGKXQ7PL'),
    (1027, '350203830040305'),
    (1027, '351152761138753'),
    (1027, '353896501332799'),
    (1027, '4SCS7U4SP6LY'),
    (1027, 'TL7FBYEJR8KW'),
    (1028, '351671552930128'),
    (1028, '359871988904216');

-- Co-owned devices (Lucas Silva and Isabella Costa share an address).
-- Delete this block if each device may only have one owner.
INSERT INTO Client_Device (client_id, device_serial_number_or_IMEI) VALUES
    (1006, 'DJRWWQSTAULT'),
    (1008, '350159450283163');

-- Devices brought in for repair, owned by the client on each service ticket.
INSERT INTO Client_Device (client_id, device_serial_number_or_IMEI) VALUES
    (1001, 'R58M30XYZ7W'),
    (1002, 'C02G84J2Q05D'),
    (1003, '862047041289563'),
    (1004, 'PF39K7LA'),
    (1005, '352099118492014'),
    (1006, '990000862471850'),
    (1007, '2948201A83B4'),
    (1008, 'H3XKJ94W7V'),
    (1009, '867531024680135'),
    (1010, 'C02F93K1MD6T'),
    (1011, '7B8N4Y2'),
    (1012, 'R58N20ABC1X'),
    (1013, '356938035643809'),
    (1014, 'PF48X90L'),
    (1015, 'DMPX81G9Q1GC'),
    (1016, 'R58K10M99YZ'),
    (1017, '082910481920'),
    (1018, '354910284719028'),
    (1019, 'M4NR901B1829'),
    (1020, '359018274019283'),
    (1021, 'SN591028301'),
    (1022, '5CD1298XLM'),
    (1023, '861928471029481'),
    (1024, '004928172948'),
    (1025, 'C02K9018MD8R'),
    (1026, '6PN019284'),
    (1027, '864910293847561'),
    (1028, '492019382019'),
    (1029, 'NHQ8X01928'),
    (1030, '992019284019283'),
    (1001, 'DMPZ8019KD84'),
    (1002, '492018471920'),
    (1003, '861920384719204'),
    (1004, '8H92KP3'),
    (1005, '990182740192834'),
    (1006, '294810294819');

-- 3. INSERT STATEMENTS
INSERT INTO Employee (employee_id, name) VALUES 
    (1, 'Hans'), (2, 'Alan'), (3, 'Don'), (4, 'Jerry'),
    (5, 'Cole'), (6, 'Tom'), (7, 'Loki'), (8, 'George');

INSERT INTO Technician (employee_id, specialization, certification_level, billing_rate) VALUES 
    (1, 'Displays', 1, 10.00),
    (2, 'Batteries', 2, 5.00),
    (3, 'Audio Drivers', 1, 15.50),
    (4, 'Enclosures', 2, 12.00),
    (5, 'Flex Cables', 1, 8.00);

INSERT INTO Workshop_Manager (employee_id) VALUES (6), (7);

-- Fixed: Assigned Managers 6 and 7 to Workstations
INSERT INTO Workstation (workstation_id, workshop_floor, equipped_for, status, manager_id) VALUES 
    (1, 1, 'ESD Safe Mobile Bench', 'Occupied', 6),
    (2, 1, 'ESD Safe Mobile Bench', 'Free', 6),
    (3, 1, 'ESD Safe Mobile Bench', 'Maintenance', 6),
    (4, 2, 'Cleanroom Screen Station', 'Occupied', 7),
    (5, 2, 'Cleanroom Screen Station', 'Free', 7),
    (6, 2, 'Cleanroom Screen Station', 'Maintenance', 7),
    (7, 3, 'Micro-Soldering Desk', 'Occupied', 6),
    (8, 3, 'Micro-Soldering Desk', 'Free', 6),
    (9, 3, 'Micro-Soldering Desk', 'Maintenance', 6),
    (10, 4, 'Audio Testing Station', 'Occupied', 7),
    (11, 4, 'Audio Testing Station', 'Free', 7),
    (12, 4, 'Audio Testing Station', 'Maintenance', 7);

INSERT INTO Service_Ticket (ticket_id, client_id, received_date_time, problem_description, status, estimated_repair_cost, workstation_id, serial_number_or_IMEI) VALUES
    (1, 1001, '2026-08-11 09:15:00', 'Device drains rapidly from 100% to shutoff within an hour and fails to hold charge overnight.', 'Ready for Pickup', 62.99, NULL, 'R58M30XYZ7W'),
    (2, 1002, '2026-09-02 14:20:00', 'Left speaker produces heavy buzzing and severe distortion at medium volume; crackles intermittently during playback.', 'Ready for Pickup', 152.57, NULL, 'C02G84J2Q05D'),
    (3, 1003, '2026-09-23 10:45:00', 'Screen flickers with green lines after accidental water splash near charging port; touchscreen intermittently unresponsive.', 'Ready for Pickup', 205.00, NULL, '862047041289563'),
    (4, 1004, '2026-09-30 08:30:00', 'Tablet suffered an accidental drop causing a fractured LCD panel and a black screen even though it still vibrates and chimes on power-up; aluminum chassis corner is bent and the internal display flex connector appears loose.', 'Ready for Pickup', 670.98, NULL, 'PF39K7LA'),
    (5, 1005, '2026-08-12 11:10:00', 'Front glass cracked after drop onto concrete; lower third of touchscreen is unresponsive to touch input.', 'Ready for Pickup', 185.50, NULL, '352099118492014'),
    (6, 1006, '2026-08-14 15:25:00', 'OLED screen is detaching and lifting from casing due to an expanding battery; watch shuts down when removed from charger.', 'Ready for Pickup', 115.00, NULL, '990000862471850'),
    (7, 1007, '2026-08-18 10:05:00', 'Active Noise Cancellation emits high-pitched acoustic squeal when turned on; right earbud cuts out intermittently over Bluetooth.', 'Ready for Pickup', 140.00, NULL, '2948201A83B4'),
    (8, 1008, '2026-08-20 16:40:00', 'Right earbud produces continuous static noise during transparency mode; charging case fails to recognize Qi wireless pads.', 'Ready for Pickup', 95.00, NULL, 'H3XKJ94W7V'),
    (9, 1009, '2026-08-22 09:50:00', 'Device dropped into chlorinated swimming pool; completely dead with no power draw on USB ammeter; moisture visible behind camera lens.', 'Ready for Pickup', 310.00, NULL, '867531024680135'),
    (10, 1010, '2026-08-25 13:15:00', 'Headband frame bent and left earcup housing cracked after being crushed in a backpack; left driver rattles severely when volume exceeds 50%.', 'Ready for Pickup', 275.50, NULL, 'C02F93K1MD6T'),
    (11, 1011, '2026-08-28 14:00:00', 'Coffee spilled over the tablet while docked in its keyboard cover; tablet shut off immediately and refuses to power on; pogo connector shows sticky residue.', 'Ready for Pickup', 420.00, NULL, '7B8N4Y2'),
    (12, 1012, '2026-09-01 11:30:00', 'Call recipients report voice sounds heavily muffled and distant; voice pickup unit mesh is clogged and lower microphone port appears damaged.', 'Ready for Pickup', 75.00, NULL, 'R58N20ABC1X'),
    (13, 1013, '2026-09-03 16:10:00', 'Primary wide-angle camera sensor vibrates and buzzes violently when camera app opens, causing blurry photos and unusable video.', 'Ready for Pickup', 195.00, NULL, '356938035643809'),
    (14, 1014, '2026-09-05 09:20:00', 'USB-C charging port receptacle is loose inside chassis; charging only connects when cable is held firmly at an upward angle.', 'Ready for Pickup', 160.00, NULL, 'PF48X90L'),
    (15, 1015, '2026-09-07 14:45:00', 'Screen registers erratic ghost touches opening random applications despite no visible glass cracks; volume down button stuck depressed.', 'Ready for Pickup', 180.00, NULL, 'DMPX81G9Q1GC'),
    (16, 1016, '2026-09-10 10:15:00', 'Rear sensor glass cracked; optical heart rate sensor and ECG fail to read biometric data; skin irritation caused by sharp rear edge.', 'Ready for Pickup', 88.00, NULL, 'R58K10M99YZ'),
    (17, 1017, '2026-09-12 15:30:00', 'Left yoke swivel hinge snapped off completely, exposing internal audio wiring harness; audio still works but cannot be worn on head.', 'Ready for Pickup', 90.00, NULL, '082910481920'),
    (18, 1018, '2026-09-15 11:00:00', 'Tablet fails to charge or connect to its keyboard cover through the pogo pins; pogo pin contacts show discoloration and slight scorch marks.', 'Ready for Pickup', 135.00, NULL, '354910284719028'),
    (19, 1019, '2026-09-18 16:50:00', 'Haptic motor produces a loud mechanical grinding noise on every notification; watch overheats and shuts down within 5 minutes of starting a GPS workout.', 'Ready for Pickup', 210.00, NULL, 'M4NR901B1829'),
    (20, 1020, '2026-09-21 10:30:00', 'Back glass completely shattered spiderwebbing across camera island; MagSafe inductive charging pad works intermittently through shards.', 'Ready for Pickup', 230.00, NULL, '359018274019283'),
    (21, 1021, '2026-09-24 13:40:00', 'Left earbud does not power on, does not flash LED when placed in charging cradle, and cradle LED flashes rapid amber fault code.', 'Ready for Pickup', 65.00, NULL, 'SN591028301'),
    (22, 1022, '2026-09-27 15:05:00', 'Display is bulging away from the frame along the left edge and registers phantom touches continuously; battery directly underneath appears swollen.', 'Ready for Pickup', 190.00, NULL, '5CD1298XLM'),
    (23, 1023, '2026-10-02 09:10:00', 'Display shows a black ink blot spreading from the lower edge after a drop; frame corner is dented and the screen no longer sits flush.', 'In Progress', 750.00, 4, '861928471029481'),
    (24, 1024, '2026-10-05 14:15:00', 'Multi-touch digitizer intermittently drops S Pen stroke inputs; S Pen no longer charges when attached to the rear magnetic strip.', 'Diagnosing', 260.00, NULL, '004928172948'),
    (25, 1025, '2026-10-08 11:20:00', 'Touchscreen registers double taps across the lower half after a sweet tea splash over the Smart Connector; display backlight is uneven.', 'In Progress', 340.00, 1, 'C02K9018MD8R'),
    (26, 1026, '2026-10-12 16:00:00', 'Watch altitude readings jump between -500m and +9000m during runs; fails to acquire GNSS satellite lock even in open outdoor areas.', 'In Progress', 125.00, 7, '6PN019284'),
    (27, 1027, '2026-10-15 10:40:00', 'Device only charges at standard 5W slow speed and repeatedly disconnects; fast charging handshake fails; CC pin in port looks charred.', 'Ready for Pickup', 85.00, NULL, '864910293847561'),
    (28, 1028, '2026-10-18 13:50:00', 'Right headband stepless extension slider cracked through structural plastic; headphones slip off head under normal walking motion.', 'Ready for Pickup', 80.00, NULL, '492019382019'),
    (29, 1029, '2026-10-21 15:10:00', 'Tablet boots to the home screen normally, but freezes and restarts whenever a graphics-heavy app or game is opened.', 'Ready for Pickup', 295.00, NULL, 'NHQ8X01928'),
    (30, 1030, '2026-10-24 09:05:00', 'Rotating digital crown provides no tactile haptic click feedback and does not scroll menus; press button action functions normally.', 'Ready for Pickup', 160.00, NULL, '992019284019283'),
    (31, 1001, '2026-10-24 10:15:00', 'Battery percentage drops precipitously from 80% to zero; screen is slightly lifted off the aluminum frame along the left edge.', 'Diagnosing', 175.00, NULL, 'DMPZ8019KD84'),
    (32, 1002, '2026-10-24 11:40:00', 'Left headphone ear cup has completely lost sound output; audio only plays through the right side over both Bluetooth and AUX.', 'In Progress', 95.00, 10, '492018471920'),
    (33, 1003, '2026-10-24 14:05:00', 'Periscope telephoto lens outer cover glass is shattered from a key strike in pocket; camera view shows severe glare and light flare.', 'Received', 80.00, NULL, '861920384719204'),
    (34, 1004, '2026-10-24 15:20:00', 'Tablet does not boot when the top button is pressed; screen stays black and it is not detected when connected to a computer.', 'Received', 210.00, 3, '8H92KP3'),
    (35, 1005, '2026-10-24 16:30:00', 'Display powers on and shows watch face normally, but swipe gestures and touch inputs fail to register across the top half of the screen.', 'Received', 130.00, NULL, '990182740192834'),
    (36, 1006, '2026-10-24 17:15:00', 'Right earbud will not charge inside the cradle; bottom gold charging pad appears recessed, oxidized, and discolored.', 'Received', 60.00, NULL, '294810294819');

UPDATE Service_Ticket SET workstation_id = 2 WHERE ticket_id IN (1, 5); 
UPDATE Service_Ticket SET workstation_id = 5 WHERE ticket_id IN (6, 7); 
UPDATE Service_Ticket SET workstation_id = 6 WHERE ticket_id IN (8, 9); 
UPDATE Service_Ticket SET workstation_id = 8 WHERE ticket_id IN (10, 12); 
UPDATE Service_Ticket SET workstation_id = 9 WHERE ticket_id = 13; 
UPDATE Service_Ticket SET workstation_id = 11 WHERE ticket_id = 15; 
UPDATE Service_Ticket SET workstation_id = 12 WHERE ticket_id IN (16, 21); 
UPDATE Service_Ticket SET workstation_id = 3 WHERE ticket_id = 19; 
UPDATE Service_Ticket SET workstation_id = 7 WHERE ticket_id = 2; 

INSERT INTO Diagnostic_Assessment (diagnostic_id, error_code, liquid_damage_status, battery_health_percentage, recommendation, date_time, ticket_id, employee_id) VALUES 
    (1, 202, 'Not Tripped', 15.00, 'Replace degraded lithium-ion battery pack and recalibrate power management IC.', '2026-08-12 14:10:00', 1, 1),
    (2, 318, 'Not Tripped', 60.00, 'Replace left channel transducer speaker assembly and re-seat audio daughterboard connector.', '2026-09-03 09:45:30', 2, 2),
    (3, 505, 'Tripped', 80.00, 'Replace torn display interconnect FPC ribbon cable and treat localized corrosion on socket.', '2026-09-24 16:20:10', 3, 3),
    (4, 112, 'Not Tripped', 75.00, 'Replace shattered 11-inch Liquid Retina LCD panel and swap pinched display flex cable to restore panel power and video signal.', '2026-09-30 11:15:00', 4, 4),
    (5, 419, 'Not Tripped', 74.50, 'Straighten deformed aluminum chassis corner so the replacement display sits flush and the flex cable is not sheared.', '2026-09-30 11:15:00', 4, 4),
    (6, 695, 'Not Tripped', 74.50, 'Inspect logic board display interface under microscope; replace blown backlight fuse (F1) and reflow cracked solder joints around the display connector.', '2026-09-30 11:15:00', 4, 4),
    (7, 119, 'Not Tripped', 91.50, 'Replace fractured front cover glass and laminated AMOLED touch digitizer panel assembly; calibrate under-display optical fingerprint scanner.', '2026-08-12 14:35:00', 5, 1),
    (8, 203, 'Not Tripped', 52.00, 'Safely extract expanded lithium polymer battery, reseat OLED display assembly, and apply fresh perimeter adhesive gasket.', '2026-08-14 17:10:00', 6, 2),
    (9, 302, 'Not Tripped', 88.00, 'Replace defective feedback microphone capsule in right earbud and calibrate ANC active noise filter firmware.', '2026-08-18 13:45:00', 7, 3),
    (10, 306, 'Not Tripped', 91.00, 'Replace right earbud transducer acoustic driver assembly and inspect charging case Qi receiver coil circuit.', '2026-08-21 09:30:00', 8, 5),
    (11, 601, 'Tripped', 40.00, 'Run logic board through ultrasonic deoxidation wash, clear shorted ceramic bypass capacitors on main VDD rail, and replace corroded battery.', '2026-08-22 14:15:00', 9, 1),
    (12, 403, 'Not Tripped', 84.00, 'Replace cracked left earcup housing, straighten bent headband frame and replace rattling left 30mm driver unit.', '2026-08-25 16:20:00', 10, 2),
    (13, 602, 'Liquid Damage', 76.00, 'Ultrasonic clean motherboard to clear sugary liquid residue, replace corroded PMIC charging regulator chip, and replace corroded pogo connector block.', '2026-08-29 10:00:00', 11, 3),
    (14, 309, 'Not Tripped', 94.00, 'Clear acoustic canal mesh blockages and replace degraded MEMS voice pickup microphone module.', '2026-09-01 14:50:00', 12, 5),
    (15, 604, 'Not Tripped', 96.00, 'Replace ruptured optical image stabilization (OIS) voice coil actuator assembly and swap primary 48MP wide-angle camera module.', '2026-09-04 09:15:00', 13, 1),
    (16, 502, 'Not Tripped', 83.00, 'Desolder cracked surface-mount USB-C power receptacle from daughterboard, solder reinforced connector, and replace worn charging flex cable.', '2026-09-05 13:00:00', 14, 5),
    (17, 104, 'Not Tripped', 87.00, 'Replace laminated touch digitizer glass panel and realign deformed tactile volume switch actuator switch plate.', '2026-09-08 10:30:00', 15, 3),
    (18, 405, 'Not Tripped', 89.00, 'Replace fractured rear ceramic and sapphire sensor back-cover housing; verify hermetic seal with barometric pressure vacuum chamber.', '2026-09-10 15:40:00', 16, 4),
    (19, 408, 'Not Tripped', 90.00, 'Install replacement left gimbal yoke swivel arm, route internal audio wiring through pivot channel, and secure friction lock pin.', '2026-09-13 11:20:00', 17, 5),
    (20, 504, 'Not Tripped', 82.00, 'Replace scorched keyboard pogo pin connector block and replace heat-damaged internal pogo interconnect ribbon cable.', '2026-09-15 14:30:00', 18, 2),
    (21, 608, 'Not Tripped', 79.00, 'Replace worn haptic vibration motor and replace degraded thermal pad between processor shield and housing.', '2026-09-19 10:10:00', 19, 3),
    (22, 410, 'Not Tripped', 85.00, 'Laser-strip shattered rear glass panel, remove debris around camera bezel, and install replacement back glass cover with new MagSafe Qi coil.', '2026-09-21 16:15:00', 20, 4),
    (23, 205, 'Not Tripped', 12.00, 'Micro-solder replacement coin cell lithium battery into left earbud chassis and clean spring-loaded charging cradle contacts.', '2026-09-25 09:40:00', 21, 1),
    (24, 208, 'Not Tripped', 48.00, 'Carefully remove dangerously swollen lithium polymer battery, re-bond lifted display assembly, and install new OEM battery unit.', '2026-09-28 11:00:00', 22, 2),
    (25, 108, 'Not Tripped', 92.00, 'Replace full AMOLED display assembly pre-fitted to a new mid-frame and side rails.', '2026-10-02 13:50:00', 23, 3),
    (27, 610, 'Liquid Damage', 90.00, 'Decontaminate liquid intrusion around the Smart Connector, replace damaged touch digitizer, and swap uneven LED backlight diffusion sheet.', '2026-10-08 15:30:00', 25, 1),
    (28, 612, 'Not Tripped', 84.00, 'Replace obstructed barometric altimeter pressure port sensor and replace defective internal GNSS ceramic patch antenna.', '2026-10-13 09:50:00', 26, 2),
    (29, 508, 'Not Tripped', 88.00, 'Replace damaged USB-C sub-board dock assembly and main-to-sub interconnect FPC ribbon cable to restore Super Fast Charging signaling.', '2026-10-15 14:20:00', 27, 3),
    (30, 412, 'Not Tripped', 93.00, 'Replace cracked right side headband extension slider bracket assembly and re-tension inner headband clamping spring.', '2026-10-18 17:05:00', 28, 4),
    (31, 615, 'Not Tripped', 81.00, 'Reball A14 Bionic system-on-chip with cracked solder joints and replace failing buck converter feeding the GPU core rail.', '2026-10-22 11:35:00', 29, 1),
    (32, 510, 'Not Tripped', 95.00, 'Replace digital crown optical rotary encoder flex cable assembly and clean debris from crown rotation cavity.', '2026-10-24 12:15:00', 30, 2),
    (33, 314, 'Not Tripped', 92.00, 'Replace open-circuit 30mm dynamic acoustic driver unit in left earcup and reflow audio signal ground solder pads.', '2026-10-24 13:15:00', 32, 3);

INSERT INTO Repair_Procedure (procedure_id, ticket_id, description, category) VALUES 
    (1, 1, 'Disassemble rear casing, detach depleted cell, install OEM battery.', 'Batteries'),
    (2, 2, 'Remove lower chassis, detach left audio transducer module.', 'Audio Drivers'),
    (3, 3, 'Clean board socket corrosion via ultrasonic bath.', 'Flex Cables'),
    (4, 4, 'Heat and lift display adhesive, unmount fractured LCD panel, install replacement 11-inch Liquid Retina screen, connect new display flex cable, and verify backlight operation.', 'Displays'),
    (5, 4, 'Remove internal components from the frame, reshape impacted chassis corner using a bench fixture, and check display seating surface is flat.', 'Enclosures'),
    (6, 4, 'Place logic board under inspection microscope, desolder open-circuit SMD backlight fuse, solder 0402 fast-blow fuse replacement, and reflow fractured solder joints on display connector pin rows.', 'Soldering'),
    (7, 5, 'Unmount damaged screen matrix, install OEM laminated AMOLED front display assembly, and calibrate under-display optical fingerprint scanner.', 'Displays'),
    (8, 6, 'Separate lifted OLED glass, safely extract degraded lithium-ion polymer battery pack, fit OEM battery, and cure new water-resistant perimeter adhesive gasket.', 'Batteries'),
    (9, 7, 'Open right earbud acoustic enclosure, replace feedback microphone capsule, and recalibrate ANC active filter DSP profile.', 'Audio Drivers'),
    (10, 8, 'Open right earbud casing, desolder defective acoustic micro-transducer, seat replacement dynamic driver, and verify charging case Qi inductive coil loop.', 'Audio Drivers'),
    (11, 9, 'Perform multi-stage ultrasonic deoxidation on logic board, desolder shorted ceramic bypass capacitors on VDD rail, and replace corroded lithium battery.', 'Batteries'),
    (12, 10, 'Fixture-clamp bent headband frame to restore clamping alignment, transfer components into a replacement left earcup housing, and install new 30mm driver unit.', 'Enclosures'),
    (13, 11, 'Ultrasonic wash logic board to eliminate residue, reflow PMIC power rail regulator IC, and fit replacement pogo connector block.', 'Enclosures'),
    (14, 12, 'Clear acoustic canal debris mesh, desolder failing MEMS voice pickup microphone, and mount replacement microphone unit.', 'Audio Drivers'),
    (15, 13, 'Disassemble rear bracket shield, disconnect camera MIPI flex lines, and install calibrated 48MP wide-angle camera module with OIS voice coil.', 'Displays'),
    (16, 14, 'Desolder fractured surface-mount Type-C receptacle, solder reinforced structural socket, and replace worn charging flex interconnect.', 'Flex Cables'),
    (17, 15, 'Separate front display bezel, mount factory laminated multi-touch digitizer panel, and reshape deformed tactile volume button bracket.', 'Displays'),
    (18, 16, 'Remove fractured ceramic back cover, transfer biometric PPG/ECG flex sensors, mount replacement sapphire rear housing, and vacuum-test seal.', 'Enclosures'),
    (19, 17, 'Install replacement reinforced left gimbal yoke swivel arm, route internal stranded audio harness through pivot cavity, and insert retention pin.', 'Enclosures'),
    (20, 18, 'Unseat rear contact plate, replace scorched keyboard spring pogo pin terminal block, and route replacement internal interconnect flex ribbon.', 'Flex Cables'),
    (21, 19, 'Separate display from housing, install replacement haptic vibration motor, and apply new thermal pad over the processor shield.', 'Enclosures'),
    (22, 20, 'Laser-ablate fractured rear glass, clear glass dust around camera bezel, and fuse replacement ceramic shield back glass with integrated MagSafe flex coil.', 'Enclosures'),
    (23, 21, 'Microsolder replacement rechargeable lithium coin-cell cell into left earbud battery housing and clean cradle charging pin contacts.', 'Batteries'),
    (24, 22, 'Extract swollen lithium polymer pack, re-bond lifted display to the frame with fresh adhesive, and mount replacement battery unit.', 'Batteries'),
    (25, 23, 'Extract damaged display panel, transfer internal components into the replacement mid-frame, and install OEM pre-assembled AMOLED display module.', 'Displays'),
    (27, 25, 'Open display, clean sugary residue from Smart Connector and logic board, install replacement touch digitizer, and seat new optical backlight diffuser sheet.', 'Displays'),
    (28, 26, 'Replace clogged barometric altimeter sensor membrane and solder replacement multi-band GNSS ceramic patch antenna flex.', 'Flex Cables'),
    (29, 27, 'Unseat charred bottom dock sub-board, install new USB-C daughterboard, and link high-speed Super Fast Charging main-to-sub FPC flex ribbon.', 'Flex Cables'),
    (30, 28, 'Disassemble right headband slider collar, install replacement stepless extension arm bracket, and re-tension internal clamping leaf spring.', 'Enclosures'),
    (31, 29, 'Reball A14 Bionic system-on-chip ball grid array, replace failing buck switching regulator IC on GPU core rail, and run graphics stress test.', 'Flex Cables'),
    (32, 30, 'Clean foreign debris from digital crown cavity, align haptic click actuator, and replace optical rotary encoder flex ribbon circuit.', 'Flex Cables'),
    (33, 32, 'Dismantle left earcup housing, desolder dead 30mm dynamic driver leads, solder replacement OEM acoustic driver unit, and test channel balance across frequency range.', 'Audio Drivers');

INSERT INTO Work_Session (procedure_id, employee_id, start_time, end_time, billable_hours) VALUES 
    (1, 2, '2026-08-13 10:00:00', '2026-08-13 11:00:00', 1),
    (2, 3, '2026-09-04 13:30:00', '2026-09-04 16:30:00', 3),
    (3, 5, '2026-09-25 11:30:15', '2026-09-25 16:30:15', 5),
    (4, 1, '2026-09-30 16:30:55', '2026-09-30 20:30:55', 4),
    (5, 4, '2026-09-30 16:30:55', '2026-09-30 20:30:55', 4),
    (6, 5, '2026-09-30 16:30:55', '2026-09-30 20:30:55', 4),
    (7, 1, '2026-08-12 15:30:00', '2026-08-12 17:30:00', 2),
    (8, 2, '2026-08-15 09:30:00', '2026-08-15 10:30:00', 1),
    (9, 3, '2026-08-18 14:30:00', '2026-08-18 16:30:00', 2),
    (10, 4, '2026-08-21 10:30:00', '2026-08-21 12:30:00', 2),
    (11, 1, '2026-08-23 09:00:00', '2026-08-23 13:00:00', 4),
    (12, 5, '2026-08-26 10:00:00', '2026-08-26 13:00:00', 3),
    (13, 3, '2026-08-29 11:30:00', '2026-08-29 16:30:00', 5),
    (14, 4, '2026-09-01 15:30:00', '2026-09-01 16:30:00', 1),
    (15, 1, '2026-09-04 10:00:00', '2026-09-04 12:00:00', 2),
    (16, 2, '2026-09-05 14:00:00', '2026-09-05 16:00:00', 2),
    (17, 5, '2026-09-08 13:00:00', '2026-09-08 16:00:00', 3),
    (18, 4, '2026-09-11 09:30:00', '2026-09-11 11:30:00', 2),
    (19, 1, '2026-09-13 13:00:00', '2026-09-13 15:00:00', 2),
    (20, 2, '2026-09-15 15:30:00', '2026-09-15 17:30:00', 2),
    (21, 3, '2026-09-19 11:00:00', '2026-09-19 14:00:00', 3),
    (22, 4, '2026-09-22 09:30:00', '2026-09-22 12:30:00', 3),
    (23, 1, '2026-09-25 10:30:00', '2026-09-25 12:30:00', 2),
    (24, 2, '2026-09-28 13:30:00', '2026-09-28 15:30:00', 2),
    (25, 1, '2026-10-20 09:00:00', '2026-10-20 10:30:00', 1.50), -- ticket 23, workstation 4, Smartphone 
    (27, 2, '2026-10-21 13:00:00', '2026-10-21 15:00:00', 2.00), -- ticket 25, workstation 1, Tablet 
    (28, 4, '2026-10-22 10:00:00', '2026-10-22 11:00:00', 1.00), -- ticket 26, workstation 7, Smartwatch 
    (33, 3, '2026-10-24 14:00:00', '2026-10-24 16:30:00', 2.50), -- ticket 32, workstation 10, Headphones 
    (28, 2, '2026-10-24 12:15:00', NULL, NULL),
    (29, 3, '2026-10-15 15:00:00', '2026-10-15 17:00:00', 2),
    (30, 4, '2026-10-19 09:30:00', '2026-10-19 10:30:00', 1),
    (31, 1, '2026-10-22 13:00:00', '2026-10-22 17:00:00', 4),
    (32, 2, '2026-10-24 14:00:00', '2026-10-24 16:00:00', 2),
    (1, 4, '2026-08-14 10:00:00', '2026-08-14 10:45:00', 0.75);

-- Tax rates by billing date. Billing_Statement has a foreign key to this table,
-- so these rows must exist first. Each rate is 9%.
INSERT INTO Tax_Rate_By_Date (billing_date, sales_tax_rate) VALUES
    ('2026-08-13', 0.0900),
    ('2026-08-15', 0.0900),
    ('2026-08-16', 0.0900),
    ('2026-08-19', 0.0900),
    ('2026-08-22', 0.0900),
    ('2026-08-24', 0.0900),
    ('2026-08-27', 0.0900),
    ('2026-08-30', 0.0900),
    ('2026-09-02', 0.0900),
    ('2026-09-05', 0.0900),
    ('2026-09-26', 0.0900),
    ('2026-10-01', 0.0900);

-- Billing statements. The tax rate is looked up through billing_date, so the
-- sales_tax_rate, net_balance_due and payment_status columns from the original
-- inserts are removed (they are not columns in Billing_Statement).
-- Each bill is dated the day after the ticket's last work session.
INSERT INTO Billing_Statement (ticket_id, billing_date, total_labor_charges, total_component_costs, promotional_discounts) VALUES
    (1, '2026-08-15', 142.50, 19.90, 8.12),
    (2, '2026-09-05', 352.50, 116.84, 10.00),
    (3, '2026-09-26', 136.00, 66.57, 0.00),
    (4, '2026-10-01', 33.75, 52.90, 4.33),
    (5, '2026-08-13', 110.00, 37.90, 15.00),
    (6, '2026-08-16', 174.00, 199.90, 0.00),
    (7, '2026-08-19', 165.00, 48.90, 10.70),
    (8, '2026-08-22', 102.00, 110.80, 10.64),
    (9, '2026-08-24', 85.00, 229.90, 15.75),
    (10, '2026-08-27', 56.25, 79.90, 0.00),
    (11, '2026-08-30', 87.00, 109.90, 0.00),
    (12, '2026-09-02', 356.50, 239.80, 0.00);

-- Warranty claims, each submitted within 90 days of its bill
INSERT INTO Warranty_Claim (claim_id, ticket_id, submission_date, description, review_status, approved_remedy, refund_value) VALUES
    (1001, 1, '2026-09-10', 'New battery drains overnight again', 'Approved', 'Partial refund of labour charge', 150.00),
    (1002, 2, '2026-09-28', 'Speaker buzzing returned at medium volume', 'Approved', 'Refund of speaker replacement', 120.00),
    (1003, 3, '2026-10-14', 'Green lines flicker across the screen again', 'Approved', 'Free re-repair of display connector', NULL),
    (1004, 4, '2026-10-19', 'Display flickers when the tablet is tilted', 'Rejected', NULL, 40.00),
    (1005, 5, '2026-09-01', 'Touch unresponsive near the bottom edge of new screen', 'Rejected', NULL, 90.00),
    (1006, 6, '2026-09-08', 'Dead pixel cluster on new display', 'Rejected', NULL, 80.00),
    (1007, 7, '2026-09-15', 'ANC squeal returned in right earbud', 'Approved', 'Partial refund', 45.00),
    (1008, 8, '2026-09-20', 'Static noise returned in right earbud', 'Approved', 'Full refund of repair', 200.00),
    (1009, 9, '2026-10-20', 'Battery holds less than 4 hours', 'Under Review', NULL, 60.00),
    (1010, 10, '2026-09-24', 'Left earcup rattles again at high volume', 'Approved', 'Driver reseated free of charge', NULL),
    (1011, 11, '2026-10-05', 'Tablet shuts off randomly while charging', 'Approved', 'Power regulator re-replacement under warranty', NULL),
    (1012, 12, '2026-10-22', 'Callers report muffled voice again', 'Under Review', NULL, 0.00);

WITH OmniTable AS (
    SELECT Workstation.workstation_id AS workstation_id, 
        DATEDIFF(minute, Work_Session.start_time, Work_Session.end_time) AS duration_minutes, 
        Device_Type.device_category AS device_category
    FROM Workstation, Service_Ticket, Repair_Procedure, Work_Session, Device, Device_Type
    WHERE Workstation.workstation_id = Service_Ticket.workstation_id
        AND Service_Ticket.ticket_id = Repair_Procedure.ticket_id
        AND Work_Session.procedure_id = Repair_Procedure.procedure_id
        AND Service_Ticket.serial_number_or_IMEI = Device.serial_number_or_IMEI
        AND Device.model_name = Device_Type.model_name
        AND Device.manufacturer_name = Device_Type.manufacturer_name 
)
SELECT workstation_id, COUNT(duration_minutes) AS Number_Entries, device_category
FROM OmniTable
WHERE duration_minutes < 180
GROUP BY workstation_id, device_category
ORDER BY workstation_id, device_category;
