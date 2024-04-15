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
    AccountNumber INT PRIMARY KEY AUTO_INCREMENT NOT NULL,
    UserID INT,
    AccountTypeID INT,
    Balance DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    CONSTRAINT Unique_Account_User UNIQUE (UserID, AccountTypeID),
    FOREIGN KEY (UserID) REFERENCES Users(UserID),
    FOREIGN KEY (AccountTypeID) REFERENCES AccountTypes(AccountTypeID)
);

INSERT INTO AccountTypes (AccountTypeID, TypeName, InterestRate, MonthlyFee)
VALUES (1, 'Savings', 1.5, 0.00);

INSERT INTO AccountTypes (AccountTypeID, TypeName, InterestRate, MonthlyFee)
VALUES (2, 'Checking', 0.5, 0.00);




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
    IN p_Username VARCHAR(50),
    IN p_FirstName VARCHAR(50),
    IN p_LastName VARCHAR(50),
    IN p_Email VARCHAR(100)
)
BEGIN
    DECLARE CreatedUserID INT;

    -- Check for existing username or email
    IF EXISTS (SELECT 1 FROM Users WHERE Username = p_Username OR Email = p_Email) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Username or Email already exists.';
    ELSE
        INSERT INTO Users (Username, FirstName, LastName, Email)
        VALUES (p_Username, p_FirstName, p_LastName, p_Email);

        SET CreatedUserID = LAST_INSERT_ID();

        SELECT CreatedUserID AS CreatedUserID; -- Return the created user ID
    END IF;
END //


DROP PROCEDURE IF EXISTS CreateAccount;
CREATE PROCEDURE CreateAccount(
    IN UserID INT,
    IN AccountTypeID INT,
    IN InitialBalance DECIMAL(10, 2)
)
BEGIN
    DECLARE ExistsCount INT;

    SELECT COUNT(*) INTO ExistsCount FROM Users WHERE UserID = UserID;

    IF ExistsCount = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User does not exist.';
    ELSE
        INSERT INTO Accounts (UserID, AccountTypeID, Balance)
        VALUES (UserID, AccountTypeID, InitialBalance);
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



-- Test successful user creation
CALL CreateUser('john.doe', 'John', 'Doe', 'john.doe@email.com');

-- Test with username exceeding character limit (assuming username is VARCHAR(50))
CALL CreateUser('ThisUsernameIsTooLongToBeValid', 'Jane', 'Doe', 'jane.doe@email.com');

-- Test with invalid email format
CALL CreateUser('jane.doe', 'Jane', 'Doe', 'invalidemail');

-- Test duplicate username
CALL CreateUser('john.doe', 'Alice', 'Smith', 'another@email.com');

-- Test duplicate email
CALL CreateUser('jol', 'jol', 'jol', 'jol@gmail.com');
-- Test successful account creation with valid AccountTypeID (replace 1 with actual ID)
CALL CreateAccount(1, 1, 100.00);

-- Test creating an account for a non-existent user
CALL CreateAccount(2, 1, 50.00);

-- Test successful deposit
CALL Deposit(1, 50.00);

-- Test deposit with a negative amount
CALL Deposit(1, -20.00);
CALL Deposit(1, 2000.00);

-- Test deposit into a non-existent account
CALL Deposit(2, 50.00);
CALL Deposit(2, 500.00);

-- Test successful withdrawal with sufficient balance
CALL Withdraw(1, 20.00);

-- Test withdrawal with insufficient balance
CALL Withdraw(1, 150.00);

-- Test withdrawal from a non-existent account
CALL Withdraw(2, 50.00);
-- Test successful fund transfer between accounts
CALL SendFunds(1, 2, 10.00);

-- Test sending funds to a non-existent account
CALL SendFunds(1, 2, 10.00);

-- Test sending funds with insufficient balance in source account
CALL SendFunds(1, 2, 200.00);
