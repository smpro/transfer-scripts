CREATE OR REPLACE TRIGGER FILES_CREATED_AI
AFTER INSERT ON FILES_CREATED
FOR EACH ROW
BEGIN
     IF :NEW.PRODUCER = 'StorageManager' THEN
         UPDATE SM_SUMMARY
	    SET S_LUMISECTION = S_LUMISECTION + NVL(:NEW.LUMISECTION,0),
	        S_CREATED = S_CREATED + 1,
		M_INSTANCE = GREATEST(:NEW.INSTANCE, NVL(M_INSTANCE, 0)),
		START_WRITE_TIME =  LEAST(:NEW.CTIME, NVL(START_WRITE_TIME,:NEW.CTIME)),
		LAST_UPDATE_TIME = sysdate
	 WHERE RUNNUMBER = :NEW.RUNNUMBER AND STREAM= :NEW.STREAM;
	 IF SQL%ROWCOUNT = 0 THEN
	    INSERT INTO SM_SUMMARY (
		RUNNUMBER,
                STREAM,
		SETUPLABEL,
		APP_VERSION,
		S_LUMISECTION,
		S_CREATED,
                N_INSTANCE,
		M_INSTANCE,
		START_WRITE_TIME,
		LAST_UPDATE_TIME)
	    VALUES (
		:NEW.RUNNUMBER,
		:NEW.STREAM,
		:NEW.SETUPLABEL,
		:NEW.APP_VERSION,
		:NEW.LUMISECTION,
                1,
		1,
		:NEW.INSTANCE,
		:NEW.CTIME,
		 sysdate);
	 END IF;
	 UPDATE SM_INSTANCES
            SET N_CREATED = N_CREATED + 1
         WHERE RUNNUMBER = :NEW.RUNNUMBER AND INSTANCE = :NEW.INSTANCE;
         IF SQL%ROWCOUNT = 0 THEN
            INSERT INTO SM_INSTANCES (
                RUNNUMBER,
                INSTANCE,
                N_CREATED,
                SETUPLABEL)
            VALUES (
                :NEW.RUNNUMBER,
                :NEW.INSTANCE,
                1,
                :NEW.SETUPLABEL);
         END IF; 
     END IF;	
END;
/

CREATE OR REPLACE TRIGGER FILES_DELETED_AI
AFTER INSERT ON FILES_DELETED
FOR EACH ROW
DECLARE 
v_producer VARCHAR(30);
v_stream VARCHAR(30);
v_instance NUMBER(5);
v_runnumber NUMBER(10);
BEGIN
     SELECT PRODUCER, STREAM, INSTANCE, RUNNUMBER into v_producer, v_stream, v_instance, v_runnumber FROM FILES_CREATED WHERE FILENAME = :NEW.FILENAME;
     IF v_producer = 'StorageManager' THEN
     	UPDATE SM_SUMMARY
        	SET S_DELETED = NVL(S_DELETED,0) + 1,
	    	LAST_UPDATE_TIME = sysdate
      	WHERE RUNNUMBER = v_runnumber AND STREAM=v_stream;
      	IF SQL%ROWCOUNT = 0 THEN
	  	NULL;
      	END IF;
        UPDATE SM_INSTANCES
                SET N_DELETED = NVL(N_DELETED,0) + 1
        WHERE RUNNUMBER = v_runnumber AND INSTANCE = v_instance;
        IF SQL%ROWCOUNT = 0 THEN
                NULL;
        END IF;
     END IF;
END;
/

CREATE OR REPLACE TRIGGER FILES_INJECTED_AI
AFTER INSERT ON FILES_INJECTED
FOR EACH ROW
DECLARE 
v_producer VARCHAR(30);
v_stream VARCHAR(30);
v_instance NUMBER(5);
v_runnumber NUMBER(10);
BEGIN
     SELECT PRODUCER, STREAM, INSTANCE, RUNNUMBER into v_producer, v_stream, v_instance, v_runnumber FROM FILES_CREATED WHERE FILENAME = :NEW.FILENAME;
     IF v_producer = 'StorageManager' THEN
     	UPDATE SM_SUMMARY
        	SET S_NEVENTS = NVL(S_NEVENTS,0) + NVL(:NEW.NEVENTS,0),
            	S_FILESIZE = NVL(S_FILESIZE,0) + NVL(:NEW.FILESIZE,0),
            	S_FILESIZE2D = NVL(S_FILESIZE2D,0) + NVL(:NEW.FILESIZE,0),
            	S_INJECTED = NVL(S_INJECTED,0) + 1,
                N_INSTANCE = (SELECT COUNT(DISTINCT INSTANCE) FROM FILES_CREATED WHERE RUNNUMBER = v_runnumber AND STREAM = v_stream),
	    	STOP_WRITE_TIME = GREATEST(:NEW.ITIME, NVL(STOP_WRITE_TIME, :NEW.ITIME)),
	    	HLTKEY = NVL(HLTKEY, :NEW.COMMENT_STR),
            	LAST_UPDATE_TIME = sysdate
      	WHERE RUNNUMBER = v_runnumber AND STREAM=v_stream;
     	IF SQL%ROWCOUNT = 0 THEN
         	NULL;
     	END IF;
        UPDATE SM_INSTANCES
                SET N_INJECTED = NVL(N_INJECTED,0) + 1,
                LAST_WRITE_TIME = GREATEST(:NEW.ITIME, NVL(LAST_WRITE_TIME, :NEW.ITIME))
        WHERE RUNNUMBER = v_runnumber AND INSTANCE = v_instance;
        IF SQL%ROWCOUNT = 0 THEN
                NULL;
        END IF;
     END IF;
END;
/

CREATE OR REPLACE TRIGGER FILES_TRANS_CHECKED_AI
AFTER INSERT ON FILES_TRANS_CHECKED
FOR EACH ROW
DECLARE 
v_producer VARCHAR(30);
v_stream VARCHAR(30);
v_instance NUMBER(5);
v_runnumber NUMBER(10);
BEGIN
     SELECT PRODUCER, STREAM, INSTANCE, RUNNUMBER into v_producer, v_stream, v_instance, v_runnumber FROM FILES_CREATED WHERE FILENAME = :NEW.FILENAME;
     IF v_producer = 'StorageManager' THEN
     	UPDATE SM_SUMMARY
        	SET S_CHECKED = NVL(S_CHECKED,0) + 1,
            	START_REPACK_TIME = LEAST(:NEW.ITIME, NVL(START_REPACK_TIME,:NEW.ITIME)),
	    	LAST_UPDATE_TIME = sysdate       
      	WHERE RUNNUMBER = v_runnumber AND STREAM=v_stream;
     	IF SQL%ROWCOUNT = 0 THEN
         	NULL;
     	END IF;
        UPDATE SM_INSTANCES
                SET N_CHECKED = NVL(N_CHECKED,0) + 1
        WHERE RUNNUMBER = v_runnumber AND INSTANCE = v_instance;
        IF SQL%ROWCOUNT = 0 THEN
                NULL;
        END IF;
     END IF;
END;
/

CREATE OR REPLACE TRIGGER FILES_TRANS_COPIED_AI
AFTER INSERT ON FILES_TRANS_COPIED
FOR EACH ROW
DECLARE
v_producer VARCHAR(30);
v_stream VARCHAR(30);
v_instance NUMBER(5);
v_runnumber NUMBER(10);
BEGIN
     SELECT PRODUCER, STREAM, INSTANCE, RUNNUMBER into v_producer, v_stream, v_instance, v_runnumber FROM FILES_CREATED WHERE FILENAME = :NEW.FILENAME;
     IF v_producer = 'StorageManager' THEN
     	UPDATE SM_SUMMARY
        	SET S_COPIED = NVL(S_COPIED,0) + 1,
	    	STOP_TRANS_TIME = GREATEST(:NEW.ITIME, NVL(STOP_TRANS_TIME, :NEW.ITIME)),
            	S_FILESIZE2T0 = NVL(S_FILESIZE2T0,0) + 
			NVL((SELECT FILESIZE from FILES_INJECTED where FILENAME = :NEW.FILENAME),0),
            	LAST_UPDATE_TIME = sysdate
      	WHERE RUNNUMBER = v_runnumber AND STREAM=v_stream;
     	IF SQL%ROWCOUNT = 0 THEN
         	NULL;
     	END IF;
        UPDATE SM_INSTANCES
                SET N_COPIED = NVL(N_COPIED,0) + 1
        WHERE RUNNUMBER = v_runnumber AND INSTANCE=v_instance;
        IF SQL%ROWCOUNT = 0 THEN
                NULL;
        END IF;
     END IF;
END;
/

CREATE OR REPLACE TRIGGER FILES_TRANS_NEW_AI
AFTER INSERT ON FILES_TRANS_NEW
FOR EACH ROW
DECLARE 
v_producer VARCHAR(30);
v_stream VARCHAR(30);
v_instance NUMBER(5);
v_runnumber NUMBER(10);
BEGIN
     SELECT PRODUCER, STREAM, INSTANCE, RUNNUMBER into v_producer, v_stream, v_instance, v_runnumber FROM FILES_CREATED WHERE FILENAME = :NEW.FILENAME;
     IF v_producer = 'StorageManager' THEN
     	UPDATE SM_SUMMARY
        	SET S_NEW = NVL(S_NEW,0) + 1,
	    	START_TRANS_TIME =  LEAST(:NEW.ITIME, NVL(START_TRANS_TIME,:NEW.ITIME)),
            	LAST_UPDATE_TIME = sysdate
      	WHERE RUNNUMBER = v_runnumber AND STREAM=v_stream;
     	IF SQL%ROWCOUNT = 0 THEN
         	NULL;
     	END IF;
        UPDATE SM_INSTANCES
                SET N_NEW = NVL(N_NEW,0) + 1
        WHERE RUNNUMBER = v_runnumber AND INSTANCE = v_instance;
        IF SQL%ROWCOUNT = 0 THEN
                NULL;
        END IF;
     END IF;
END;
/

CREATE OR REPLACE TRIGGER FILES_TRANS_REPACKED_AI
AFTER INSERT ON FILES_TRANS_REPACKED
FOR EACH ROW
DECLARE 
v_producer VARCHAR(30);
v_stream VARCHAR(30);
v_instance NUMBER(5);
v_runnumber NUMBER(10);
BEGIN
     SELECT PRODUCER, STREAM, INSTANCE, RUNNUMBER into v_producer, v_stream, v_instance, v_runnumber FROM FILES_CREATED WHERE FILENAME = :NEW.FILENAME;
     IF v_producer = 'StorageManager' THEN
     	UPDATE SM_SUMMARY
        	SET S_REPACKED = NVL(S_REPACKED,0) + 1,
	    	STOP_REPACK_TIME = :NEW.ITIME,
	    	LAST_UPDATE_TIME = sysdate
      	WHERE RUNNUMBER = v_runnumber AND STREAM=v_stream;
     	IF SQL%ROWCOUNT = 0 THEN
        	 NULL;
     	END IF;
        UPDATE SM_INSTANCES
                SET N_REPACKED = NVL(N_REPACKED,0) + 1
        WHERE RUNNUMBER = v_runnumber AND INSTANCE=v_instance;
        IF SQL%ROWCOUNT = 0 THEN
                NULL;
        END IF;
     END IF;
END;
/
