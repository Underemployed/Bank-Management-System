drop database if exists bank;
Create database bank;
use bank;

-- Create Users table
CREATE TABLE Users (
    UserID INT AUTO_INCREMENT PRIMARY KEY,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Email VARCHAR(100) UNIQUE,
    Password VARCHAR(255)
);


-- Create Accounts table
CREATE TABLE Accounts (
    AccountNumber INT PRIMARY KEY AUTO_INCREMENT,
    UserID INT,
    Balance DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    FOREIGN KEY (UserID) REFERENCES Users(UserID)
);

 ALTER TABLE Accounts AUTO_INCREMENT=9770; 

-- Create Transactions table
CREATE TABLE Transactions (
    TransactionID INT AUTO_INCREMENT PRIMARY KEY,
    AccountNumber INT,
    TransactionType VARCHAR(50),
    Amount DECIMAL(10, 2) NOT NULL,
    TransactionDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (AccountNumber) REFERENCES Accounts(AccountNumber)
);


-- Transaction Backups table
CREATE TABLE TransactionsBackup (
    TransactionID INT AUTO_INCREMENT PRIMARY KEY,
    TransactionType VARCHAR(50),
    Amount DECIMAL(10, 2) NOT NULL,
    TransactionDate DATETIME DEFAULT CURRENT_TIMESTAMP
);
-- =======================================================================================================================================
-- ====================================== VIIEWS =========================================================================================
-- =======================================================================================================================================
CREATE VIEW UserAccounts AS
SELECT Users.*, Accounts.AccountNumber, Accounts.Balance
FROM Users
JOIN Accounts ON Users.UserID = Accounts.UserID;
SELECT * FROM UserAccounts;


CREATE VIEW LoginPass AS
SELECT Accounts.AccountNumber, Password
FROM Users
JOIN Accounts ON Users.UserID = Accounts.UserID;
SELECT * FROM LoginPass ;
-- =======================================================================================================================================
-- ====================================== TRIGGERS =======================================================================================
-- =======================================================================================================================================
DELIMITER //

CREATE TRIGGER BackupTransaction
AFTER INSERT ON Transactions
FOR EACH ROW
BEGIN
    INSERT INTO TransactionsBackup (TransactionType, Amount, TransactionDate)
    VALUES (NEW.TransactionType, NEW.Amount, NEW.TransactionDate);
END //


CREATE TRIGGER UpdateAccountBalance
AFTER INSERT ON Transactions
FOR EACH ROW
BEGIN
    UPDATE Accounts
    SET Balance = Balance + (CASE WHEN NEW.TransactionType = 'Deposit' THEN NEW.Amount ELSE -NEW.Amount END)
    WHERE Accounts.AccountNumber = NEW.AccountNumber;
END //


-- =======================================================================================================================================
-- ====================================== PROCEDURES =====================================================================================
-- =======================================================================================================================================


DROP PROCEDURE IF EXISTS Deposit//
CREATE PROCEDURE Deposit(
    IN AccountNumber INT,
    IN Amount DECIMAL(10, 2)
)
BEGIN
    DECLARE ExistsCount INT;

    SELECT COUNT(*) INTO ExistsCount FROM Accounts WHERE AccountNumber = AccountNumber;

    IF ExistsCount = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account does not exist.';
    ELSEIF Amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Amount must be positive.';
    ELSE
        INSERT INTO Transactions (AccountNumber, TransactionType, Amount)
        VALUES (AccountNumber, 'Deposit', Amount);
    END IF;
END //


DROP PROCEDURE IF EXISTS Withdraw//
CREATE PROCEDURE Withdraw(
    IN _AccountNumber INT,
    IN Amount DECIMAL(10, 2)
)
BEGIN
    DECLARE Balance DECIMAL(10, 2);

    SELECT Balance INTO Balance FROM Accounts WHERE AccountNumber = _AccountNumber;

    IF Balance < Amount THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient funds.';
    ELSE
        INSERT INTO Transactions (AccountNumber, TransactionType, Amount)
        VALUES (_AccountNumber, 'Withdrawal', Amount);
    END IF;
END //


DROP PROCEDURE IF EXISTS CreateUser//

CREATE PROCEDURE CreateUser (
    IN p_FirstName VARCHAR(50),
    IN p_LastName VARCHAR(50),
    IN p_Email VARCHAR(100),
    IN p_Password VARCHAR(50)
)
BEGIN
    DECLARE CreatedUserID INT;

    -- Check for existing username or email
    IF EXISTS (SELECT 1 FROM Users WHERE Email = p_Email AND (FirstName = p_FirstName AND LastName =p_LastName)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Username or Email already exists.';
    ELSE
        INSERT INTO Users (FirstName, LastName, Email, Password)
        VALUES ( p_FirstName, p_LastName, p_Email, p_Password);

        SET CreatedUserID = LAST_INSERT_ID();

        SELECT CreatedUserID AS CreatedUserID;
    END IF;
END //


DROP PROCEDURE IF EXISTS CreateAccount//
CREATE PROCEDURE CreateAccount(
    IN UserID INT,
    IN InitialBalance DECIMAL(10, 2)
)
BEGIN
    DECLARE ExistsCount INT;

    SELECT COUNT(*) INTO ExistsCount FROM Users WHERE UserID = UserID;

    IF ExistsCount = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User does not exist.';
    ELSE
        INSERT INTO Accounts (UserID, Balance)
        VALUES (UserID, InitialBalance);
        
    END IF;
END //


DROP PROCEDURE IF EXISTS SendFunds//

CREATE PROCEDURE SendFunds (
    IN FromAccount INT,
    IN ToAccount INT,
    IN Amount DECIMAL(10, 2)
)
BEGIN
    DECLARE FromBalance DECIMAL(10, 2);
    DECLARE ToExists INT;

    -- Check if 'To' account exists
    SELECT COUNT(*) INTO ToExists FROM Accounts WHERE AccountNumber = ToAccount;

    IF ToExists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Destination account does not exist.';
    ELSE
        -- Check if 'From' account has sufficient balance
        SELECT Balance INTO FromBalance FROM Accounts WHERE AccountNumber = FromAccount;

        IF FromBalance < Amount THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient funds in source account.';
        ELSE
            -- Withdraw from sender account (assuming trigger updates balance)
            INSERT INTO Transactions (AccountNumber, TransactionType, Amount)
            VALUES (FromAccount, 'Withdrawal', Amount);

            -- Deposit to receiver account (assuming trigger updates balance)
            INSERT INTO Transactions (AccountNumber, TransactionType, Amount)
            VALUES (ToAccount, 'Deposit', Amount);
        END IF;
    END IF;
END //




DROP PROCEDURE IF EXISTS CreateUserAndAccount//
DELIMITER //
CREATE PROCEDURE CreateUserAndAccount (
    IN p_FirstName VARCHAR(50),
    IN p_LastName VARCHAR(50),
    IN p_Email VARCHAR(100),
    IN p_Password VARCHAR(50)
)
BEGIN
    DECLARE v_UserID INT;

    -- Check for existing email
    IF EXISTS (SELECT 1 FROM Users WHERE Email = p_Email AND (FirstName = p_FirstName AND LastName =p_LastName)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User or Email already exists.';
    ELSE
        -- Create new user
        INSERT INTO Users (FirstName, LastName, Email, Password)
        VALUES (p_FirstName, p_LastName, p_Email, p_Password);

        -- Get the ID of the newly created user
        SET v_UserID = LAST_INSERT_ID();

        -- Create new account for the user
        INSERT INTO Accounts (UserID, Balance)
        VALUES (v_UserID, 0);
            SELECT * from UserAccounts where AccountNumber = LAST_INSERT_ID();
    END IF;
END //

-- =======================================================================================================================================
-- ====================================== TESTING =====================================================================================
-- =======================================================================================================================================



DELIMITER ;


CALL CreateUser( 'Test', 'User', 'testuser@example.com', 'password123');
CALL CreateUser( '2', '2', '2@example.com', 'password123');

CALL CreateAccount(1, 1000.00); 
CALL CreateAccount(2, 1000.00); 

CALL Deposit(9770, 500.00); 

CALL Withdraw(9771, 200.00); 


CALL SendFunds(9770, 9771, 300.00);
CALL CreateUserAndAccount('John', 'Doe', 'john.doe@example.com', 'password123');


-- =======================================================================================================================================
-- ====================================== NEW STUFF =====================================================================================
-- =======================================================================================================================================
DELIMITER //
DROP PROCEDURE IF EXISTS GetTransactionHistory//
CREATE PROCEDURE GetTransactionHistory(IN _AccountNumber INT)
BEGIN
    SELECT TransactionType,Amount,TransactionDate FROM Transactions WHERE AccountNumber = _AccountNumber;
END //

CALL GetTransactionHistory(9775);//


DROP PROCEDURE IF EXISTS ChangePin;
DELIMITER //
CREATE PROCEDURE ChangePin(IN _AccountNumber INT, IN _NewPin VARCHAR(4))
BEGIN
    UPDATE Users JOIN Accounts ON Users.UserID = Accounts.UserID SET Password = _NewPin WHERE AccountNumber = _AccountNumber;
    SELECT 'PIN changed successfully.' AS Message;
END //
DELIMITER ;
CALL ChangePin(9770,  '5678');
