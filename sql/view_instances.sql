--Basically dumps all per-instance information for the last 10 runs (view has a row for each instance for each run)
create or replace view view_sm_instances
AS SELECT "RUN_NUMBER",
          "INSTANCE_NUMBER",
          "HOST_NAME",
          "UN_FILES",
          "NUM_FILES",
          "NUM_OPEN",
          "NUM_CLOSED",
          "NUM_INJECTED",
          "NUM_TRANSFERRED",
          "NUM_CHECKED",
          "NUM_DELETED",
          "NUM_REPACKED",
          "OPEN_STATUS",
          "INJECTED_STATUS",
          "TRANSFERRED_STATUS",
          "CHECKED_STATUS",
          "DELETED_STATUS",
          "RANK" 
FROM (SELECT TO_CHAR( RUNNUMBER ) AS RUN_NUMBER,
             --TO_CHAR( INSTANCE ) AS INSTANCE_NUMBER,
             INSTANCE  AS INSTANCE_NUMBER,
             TO_CHAR( HOSTNAME ) AS HOST_NAME,
             TO_CHAR( NVL(N_UNACCOUNT, 0)) AS UN_FILES,
             TO_CHAR( NVL(N_CREATED,   0)) AS NUM_FILES,
             TO_CHAR( NVL(N_CREATED,   0) - NVL(N_INJECTED,0)) AS NUM_OPEN,
             TO_CHAR( NVL(N_INJECTED,  0)) AS NUM_CLOSED,
             TO_CHAR( NVL(N_NEW,       0)) AS NUM_INJECTED,
             TO_CHAR( NVL(N_COPIED,    0)) AS NUM_TRANSFERRED,
             TO_CHAR( NVL(N_CHECKED,   0)) AS NUM_CHECKED,
             TO_CHAR( NVL(N_DELETED,   0)) AS NUM_DELETED,
             TO_CHAR( NVL(N_REPACKED,  0)) AS NUM_REPACKED,
            --These fields will return 1 if the field has a value differing from the preceding field (still active)
	    (CASE NVL(N_CREATED,0) - NVL(N_INJECTED,0)
             WHEN 0 THEN TO_CHAR(0)
             ELSE TO_CHAR(1)
             END) AS OPEN_STATUS,
            (CASE NVL(N_INJECTED, 0) - NVL(N_NEW, 0)
             WHEN 0 THEN TO_CHAR(0)
             ELSE TO_CHAR(1)
             END) AS INJECTED_STATUS,
            (CASE NVL(N_COPIED, 0) - NVL(N_INJECTED, 0)
             WHEN 0 THEN TO_CHAR(0)
             ELSE TO_CHAR(1)
             END) AS TRANSFERRED_STATUS,
            (CASE NVL(N_NEW, 0) - NVL(N_CHECKED, 0)
             WHEN 0 THEN TO_CHAR(0)
             ELSE TO_CHAR(1)
             END) AS CHECKED_STATUS,
            (CASE NVL(N_DELETED, 0) - NVL(N_CHECKED, 0)
             WHEN 0 THEN TO_CHAR(0)
             ELSE TO_CHAR(1)
             END) AS DELETED_STATUS,
             TO_CHAR( run ) as RANK
FROM (SELECT RUNNUMBER, INSTANCE, HOSTNAME, N_UNACCOUNT, N_CREATED, N_INJECTED, N_NEW, N_COPIED, N_CHECKED, N_INSERTED, N_REPACKED, N_DELETED, DENSE_RANK() OVER (ORDER BY RUNNUMBER DESC NULLS LAST) run
FROM SM_INSTANCES)
WHERE run <= 25
ORDER BY 1 DESC, 2 ASC); 

grant select on view_sm_instances to public;
