drop database if exists bank;
Create database bank;
use bank;

-- Create Users table
CREATE TABLE Users (
    UserID INT AUTO_INCREMENT PRIMARY KEY,
    Username VARCHAR(50) UNIQUE,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Email VARCHAR(100) UNIQUE
);

-- Create AccountTypes table
CREATE TABLE AccountTypes (
    AccountTypeID INT PRIMARY KEY,
    TypeName VARCHAR(50),
    InterestRate DECIMAL(5, 2) DEFAULT 0.00,
    MonthlyFee DECIMAL(10, 2) DEFAULT 0.00
);

-- Create Accounts table
CREATE TABLE Accounts (
    AccountNumber INT PRIMARY KEY,
    UserID INT,
    AccountTypeID INT,
    Balance DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    CONSTRAINT Unique_Account_User UNIQUE (UserID, AccountTypeID),
    FOREIGN KEY (UserID) REFERENCES Users(UserID),
    FOREIGN KEY (AccountTypeID) REFERENCES AccountTypes(AccountTypeID)
);





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



DROP PROCEDURE IF EXISTS Deposit;
CREATE PROCEDURE Deposit(
    IN AccountNumber INT,
    IN Amount DECIMAL(10, 2)
)
BEGIN
    DECLARE ExistsCount INT;

    SELECT COUNT(*) INTO ExistsCount FROM Accounts WHERE AccountNumber = AccountNumber;

    IF ExistsCount = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Account does not exist.';
    ELSE
        INSERT INTO Transactions (AccountNumber, TransactionType, Amount)
        VALUES (AccountNumber, 'Deposit', Amount);
    END IF;
END //



DROP PROCEDURE IF EXISTS Withdraw;
CREATE PROCEDURE Withdraw(
    IN AccountNumber INT,
    IN Amount DECIMAL(10, 2)
)
BEGIN
    DECLARE Balance DECIMAL(10, 2);

    SELECT Balance INTO Balance FROM Accounts WHERE AccountNumber = AccountNumber;

    IF Balance < Amount THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient funds.';
    ELSE
        INSERT INTO Transactions (AccountNumber, TransactionType, Amount)
        VALUES (AccountNumber, 'Withdrawal', Amount);
    END IF;
END //

DROP PROCEDURE IF EXISTS CreateUser;

CREATE PROCEDURE CreateUser (
    IN Username VARCHAR(50),
    IN FirstName VARCHAR(50),
    IN LastName VARCHAR(50),
    IN Email VARCHAR(100)
)
BEGIN
    DECLARE CreatedUserID INT;

    -- Check for existing username or email
    IF EXISTS (SELECT 1 FROM Users WHERE Username = Username OR Email = Email) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Username or Email already exists.';
    ELSE
        INSERT INTO Users (Username, FirstName, LastName, Email)
        VALUES (Username, FirstName, LastName, Email);

        SET CreatedUserID = LAST_INSERT_ID();

        SELECT CreatedUserID AS CreatedUserID; -- Return the created user ID
    END IF;
END //


DROP PROCEDURE IF EXISTS SendFunds;

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

DELIMITER ;