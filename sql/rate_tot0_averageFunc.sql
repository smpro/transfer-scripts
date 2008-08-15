CREATE OR REPLACE FUNCTION RATE2T_AVERAGE (RUNNUMBER_IN NUMBER)
  RETURN CHAR IS
  CURSOR NUM IS
  SELECT
  DECODE(time_difference,0,-999,
         ROUND(sum_filesize / time_difference,2)) AS VALUE
  FROM
  (SELECT SUM(FILESIZE)/1048576 sum_filesize
   FROM FILES_CREATED JOIN FILES_INJECTED ON FILES_CREATED.FILENAME=FILES_INJECTED.FILENAME
                      JOIN FILES_TRANS_COPIED ON FILES_CREATED.FILENAME=FILES_TRANS_COPIED.FILENAME
   WHERE RUNNUMBER = RUNNUMBER_IN AND PRODUCER='StorageManager'),
  (SELECT INT_TO_SECONDS(MAX(FILES_TRANS_COPIED.ITIME) - MIN(FILES_TRANS_NEW.ITIME)) time_difference
   FROM FILES_CREATED JOIN FILES_TRANS_NEW ON FILES_CREATED.FILENAME=FILES_TRANS_NEW.FILENAME
                      JOIN FILES_TRANS_COPIED ON FILES_CREATED.FILENAME=FILES_TRANS_COPIED.FILENAME
   WHERE RUNNUMBER = RUNNUMBER_IN AND PRODUCER='StorageManager');
  TOTAL NUMBER;
  BEGIN
  FOR X IN NUM LOOP
  TOTAL := X.VALUE;
  END LOOP;
  RETURN TO_CHAR(TOTAL);
END RATE2T_AVERAGE;

/
