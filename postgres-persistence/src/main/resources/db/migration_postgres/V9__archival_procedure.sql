CREATE OR REPLACE PROCEDURE public.conductor_archive(IN archival_date date)
 LANGUAGE plpgsql
AS $procedure$
BEGIN

    --CREATING TEMP TABLE FOR TASK IDs
    CREATE TEMP TABLE temp_task_ids ON COMMIT DROP AS
    SELECT task_id FROM task WHERE created_on < archival_date;

    ALTER TABLE temp_task_ids ADD PRIMARY KEY (task_id);
    ANALYZE temp_task_ids;

    --CREATING TEMP TABLE FOR WORKFLOW IDs
    CREATE TEMP TABLE temp_workflow_ids ON COMMIT DROP AS
    SELECT workflow_id FROM workflow WHERE created_on < archival_date;

    ALTER TABLE temp_workflow_ids ADD PRIMARY KEY (workflow_id);
    ANALYZE temp_workflow_ids;

    --CREATING TEMP TABLE FOR temp_workflow_def_to_workflow IDs
    CREATE TEMP TABLE temp_workflow_def_to_workflow_ids ON COMMIT DROP AS
    SELECT wdt.workflow_id
    FROM workflow_def_to_workflow wdt
    JOIN temp_workflow_ids tw ON tw.workflow_id = wdt.workflow_id;

    ALTER TABLE temp_workflow_def_to_workflow_ids ADD PRIMARY KEY (workflow_id);
    ANALYZE temp_workflow_def_to_workflow_ids;

    --CREATING TEMP TABLES FOR workflow_to_task IDs
    CREATE TEMP TABLE temp_workflow_to_task_ids ON COMMIT DROP AS
    SELECT w.task_id
    FROM workflow_to_task w
    JOIN temp_task_ids t ON t.task_id = w.task_id;

    ALTER TABLE temp_workflow_to_task_ids ADD PRIMARY KEY(task_id);
    ANALYZE temp_workflow_to_task_ids;

    --CREATING TEMP TABLES FOR task_scheduled IDs
    CREATE TEMP TABLE temp_task_scheduled_ids ON COMMIT DROP AS
    SELECT ts.task_id
    FROM task_scheduled ts
    JOIN temp_task_ids t ON t.task_id = ts.task_id;

    ALTER TABLE temp_task_scheduled_ids ADD PRIMARY KEY(task_id);
    ANALYZE temp_task_scheduled_ids;

    DELETE FROM task t USING temp_task_ids tti WHERE t.task_id = tti.task_id;
    DELETE FROM workflow w USING temp_workflow_ids t WHERE w.workflow_id = t.workflow_id;
    DELETE FROM workflow_def_to_workflow w USING temp_workflow_def_to_workflow_ids t WHERE w.workflow_id = t.workflow_id;
    DELETE FROM workflow_to_task w USING temp_workflow_to_task_ids t WHERE w.task_id = t.task_id;
    DELETE FROM task_scheduled t USING temp_task_scheduled_ids tts WHERE t.task_id = tts.task_id;
    DELETE FROM event_execution WHERE created_on < archival_date;
END;
$procedure$
;
