CREATE TABLE FILES_CREATED (
  FILENAME        VARCHAR2(1000) NOT NULL
 ,HOSTNAME        VARCHAR2(100)  NOT NULL
 ,SETUPLABEL      VARCHAR2(100)  NOT NULL
 ,TYPE            VARCHAR2(100)  NOT NULL
 ,STREAM          VARCHAR2(100)
 ,PRODUCER        VARCHAR2(100)
 ,APP_NAME        VARCHAR2(100)
 ,APP_VERSION     VARCHAR2(100)
 ,RUNNUMBER       NUMBER(10)
 ,LUMISECTION     NUMBER(10)
 ,COUNT           NUMBER(10)
 ,INSTANCE        NUMBER(5)
 ,CTIME           TIMESTAMP
 ,CPATH           VARCHAR2(1000)
 ,COMMENT_STR     VARCHAR2(1000)
 ,CONSTRAINT PK_FC PRIMARY KEY (FILENAME)
);

CREATE TABLE FILES_INJECTED (
  FILENAME        VARCHAR2(1000) UNIQUE NOT NULL
 ,PATHNAME        VARCHAR2(1000) NOT NULL
 ,DESTINATION     VARCHAR2(100)
 ,NEVENTS         NUMBER(20)
 ,FILESIZE        NUMBER(20)     NOT NULL
 ,CHECKSUM        VARCHAR2(50)
 ,ITIME           TIMESTAMP
 ,COMMENT_STR     VARCHAR2(1000)
 ,CONSTRAINT FK_FI FOREIGN KEY (FILENAME)
   REFERENCES FILES_CREATED (FILENAME) ON DELETE CASCADE
);

CREATE TABLE FILES_DELETED (
  FILENAME        VARCHAR2(1000) UNIQUE NOT NULL
 ,DTIME           TIMESTAMP
 ,COMMENT_STR     VARCHAR2(1000)
 ,CONSTRAINT FK_FD FOREIGN KEY (FILENAME)
   REFERENCES FILES_CREATED (FILENAME) ON DELETE CASCADE
); 

CREATE TABLE FILES_TRANS_NEW (
  FILENAME        VARCHAR2(1000) UNIQUE NOT NULL
 ,ITIME           TIMESTAMP
 ,CONSTRAINT FK_FTN FOREIGN KEY (FILENAME)
  REFERENCES FILES_CREATED (FILENAME) ON DELETE CASCADE
);

CREATE TABLE FILES_TRANS_COPIED (
  FILENAME        VARCHAR2(1000) UNIQUE NOT NULL
 ,ITIME           TIMESTAMP
 ,CONSTRAINT FK_FTCO FOREIGN KEY (FILENAME)
  REFERENCES FILES_CREATED (FILENAME) ON DELETE CASCADE
);

CREATE TABLE FILES_TRANS_CHECKED (
  FILENAME        VARCHAR2(1000) UNIQUE NOT NULL
  ,ITIME          TIMESTAMP
  ,CONSTRAINT FK_FTCH FOREIGN KEY (FILENAME)
   REFERENCES FILES_CREATED (FILENAME) ON DELETE CASCADE
);

CREATE TABLE FILES_TRANS_INSERTED (
  FILENAME        VARCHAR2(1000) UNIQUE NOT NULL
 ,ITIME           TIMESTAMP
 ,CONSTRAINT FK_FTI FOREIGN KEY (FILENAME)
  REFERENCES FILES_CREATED (FILENAME) ON DELETE CASCADE
);

CREATE TABLE FILES_TRANS_REPACKED (
  FILENAME        VARCHAR2(1000) UNIQUE NOT NULL
 ,ITIME           TIMESTAMP
 ,CONSTRAINT FK_FTR FOREIGN KEY (FILENAME)
  REFERENCES FILES_CREATED (FILENAME) ON DELETE CASCADE
); 

GRANT SELECT,INSERT ON FILES_CREATED  TO CMS_STOMGR_W;
GRANT SELECT,INSERT ON FILES_INJECTED TO CMS_STOMGR_W;
GRANT SELECT,INSERT ON FILES_DELETED  TO CMS_STOMGR_W;
GRANT SELECT ON FILES_TRANS_NEW       TO PUBLIC;
GRANT SELECT ON FILES_TRANS_COPIED    TO PUBLIC;
GRANT SELECT ON FILES_TRANS_CHECKED   TO PUBLIC;
GRANT SELECT ON FILES_TRANS_INSERTED  TO PUBLIC;
GRANT SELECT ON FILES_TRANS_REPACKED  TO PUBLIC;
