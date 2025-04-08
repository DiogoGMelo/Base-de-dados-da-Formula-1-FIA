
-- Tabela CIRCUITS
CREATE TABLE Circuits (
    CircuitID INT PRIMARY KEY,
    CircuitRef VARCHAR(100),
    Name VARCHAR(100),
    Location VARCHAR(100),
    Country VARCHAR(100),
    Lat FLOAT,
    Lng FLOAT,
    Alt INT,
    URL VARCHAR(255)
);

-- Tabela CONSTRUCTORS
CREATE TABLE Constructors (
    ConstructorID INT PRIMARY KEY,
    ConstructorRef VARCHAR(100),
    Name VARCHAR(100),
    Nationality VARCHAR(100),
    URL VARCHAR(255)
);

-- Tabela DRIVERS
CREATE TABLE Drivers (
    DriverID INT PRIMARY KEY,
    DriverRef VARCHAR(100),
    Number INT,
    Code VARCHAR(10),
    Forename VARCHAR(100),
    Surname VARCHAR(100),
    DateOfBirth DATE,
    Nationality VARCHAR(100),
    URL VARCHAR(255)
);

-- Tabela DRIVERSTANDINGS
CREATE TABLE DriverStandings (
    DriverStandingsID INT PRIMARY KEY,
    RaceID INT,
    DriverID INT,
    Points FLOAT,
    Position INT,
    PositionText VARCHAR(10),
    Wins INT,
    FOREIGN KEY (RaceID) REFERENCES Races(RaceID),
    FOREIGN KEY (DriverID) REFERENCES Drivers(DriverID)
);

-- Tabela LAPTIMES
CREATE TABLE LapTimes (
    RaceID INT,
    DriverID INT,
    Lap INT,
    Position INT,
    Time VARCHAR(20),
    Milliseconds INT,
    PRIMARY KEY (RaceID, DriverID, Lap),
    FOREIGN KEY (RaceID) REFERENCES Races(RaceID),
    FOREIGN KEY (DriverID) REFERENCES Drivers(DriverID)
);

-- Tabela PITSTOPS
CREATE TABLE PitStops (
    RaceID INT,
    DriverID INT,
    Stop INT,
    Lap INT,
    Time VARCHAR(20),
    Duration VARCHAR(20),
    Milliseconds INT,
    PRIMARY KEY (RaceID, DriverID, Stop),
    FOREIGN KEY (RaceID) REFERENCES Races(RaceID),
    FOREIGN KEY (DriverID) REFERENCES Drivers(DriverID)
);

-- Tabela QUALIFYING
CREATE TABLE Qualifying (
    QualifyID INT PRIMARY KEY,
    RaceID INT,
    DriverID INT,
    ConstructorID INT,
    Number INT,
    Position INT,
    Q1 VARCHAR(20),
    Q2 VARCHAR(20),
    Q3 VARCHAR(20),
    FOREIGN KEY (RaceID) REFERENCES Races(RaceID),
    FOREIGN KEY (DriverID) REFERENCES Drivers(DriverID),
    FOREIGN KEY (ConstructorID) REFERENCES Constructors(ConstructorID)
);

-- Tabela RACES
CREATE TABLE Races (
    RaceID INT PRIMARY KEY,
    Year INT,
    Round INT,
    CircuitID INT,
    Name VARCHAR(100),
    Date DATE,
    Time TIME,
    URL VARCHAR(255),
    FOREIGN KEY (CircuitID) REFERENCES Circuits(CircuitID),
    FOREIGN KEY (Year) REFERENCES Seasons(Year)
);

-- Tabela RESULTS
CREATE TABLE Results (
    ResultID INT PRIMARY KEY,
    RaceID INT,
    DriverID INT,
    ConstructorID INT,
    Number INT,
    Grid INT,
    Position INT,
    PositionText VARCHAR(10),
    PositionOrder INT,
    Points FLOAT,
    Laps INT,
    Time VARCHAR(50),
    Milliseconds INT,
    FastestLap INT,
    Rank INT,
    FastestLapTime VARCHAR(20),
    FastestLapSpeed FLOAT,
    StatusID INT,
    FOREIGN KEY (RaceID) REFERENCES Races(RaceID),
    FOREIGN KEY (DriverID) REFERENCES Drivers(DriverID),
    FOREIGN KEY (ConstructorID) REFERENCES Constructors(ConstructorID),
    FOREIGN KEY (StatusID) REFERENCES Status(StatusID)
);

-- Tabela SEASONS
CREATE TABLE Seasons (
    Year INT PRIMARY KEY,
    URL VARCHAR(255)
);

-- Tabela STATUS
CREATE TABLE Status (
    StatusID INT PRIMARY KEY,
    Status VARCHAR(100)
);

-- Tabela AIRPORTS
CREATE TABLE Airports (
    ID INT PRIMARY KEY,
    Ident VARCHAR(20),
    Type VARCHAR(50),
    Name VARCHAR(100),
    LatDeg FLOAT,
    LongDeg FLOAT,
    ElevFt INT,
    Continent VARCHAR(10),
    ISOCountry VARCHAR(10),
    ISORegion VARCHAR(10),
    City VARCHAR(100),
    Scheduled_service VARCHAR(10),
    GPSCode VARCHAR(10),
    IATACode VARCHAR(10),
    LocalCode VARCHAR(10),
    HomeLink VARCHAR(255),
    WikipediaLink VARCHAR(255),
    Keywords TEXT
);

-- Tabela COUNTRIES
CREATE TABLE Countries (
    ID INT PRIMARY KEY,
    Code VARCHAR(10),
    Name VARCHAR(100),
    Continent VARCHAR(50),
    WikipediaLink VARCHAR(255),
    Keywords TEXT
);

-- Tabela GEOCITIES15K
CREATE TABLE GeoCities15K (
    GeonameID INT PRIMARY KEY,
    Name VARCHAR(100),
    AsciiName VARCHAR(100),
    AlternateNames TEXT,
    Lat FLOAT,
    Long FLOAT,
    FeatureClass VARCHAR(10),
    FeatureCode VARCHAR(10),
    Country VARCHAR(10),
    CC2 VARCHAR(10),
    Admin1Code VARCHAR(20),
    Admin2Code VARCHAR(20),
    Admin3Code VARCHAR(20),
    Admin4Code VARCHAR(20),
    Population INT,
    Elevation INT,
    Dem VARCHAR(10),
    TimeZone VARCHAR(50),
    Modification DATE
);
