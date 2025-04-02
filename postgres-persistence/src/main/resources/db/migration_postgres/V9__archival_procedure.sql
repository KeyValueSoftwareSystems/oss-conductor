CREATE PROCEDURE public.siren_archive(IN archival_date DATE)
LANGUAGE plpgsql
AS $procedure$
BEGIN
    -- Create a temp table for workflow_request IDs
    CREATE TEMP TABLE temp_workflow_request_ids ON COMMIT DROP AS
    SELECT id FROM workflow_request WHERE created_at < archival_date;

    ALTER TABLE temp_workflow_request_ids ADD PRIMARY KEY (id);
    ANALYZE temp_workflow_request_ids;

    -------

    CREATE TEMP TABLE temp_workflow_execution_ids ON COMMIT DROP AS
    SELECT id FROM workflow_execution WHERE created_at < archival_date;

    ALTER TABLE temp_workflow_execution_ids ADD PRIMARY KEY (id);
    ANALYZE temp_workflow_execution_ids;
    -------

    -- Create a temp table for notification IDs
    CREATE TEMP TABLE temp_notification_ids ON COMMIT DROP AS
    SELECT n.id
    FROM notification n
    JOIN temp_workflow_execution_ids t ON n.workflow_execution_id = t.id;

    ALTER TABLE temp_notification_ids ADD PRIMARY KEY (id);
    ANALYZE temp_notification_ids;

    -- Create a temp table for notification_audit IDs
    CREATE TEMP TABLE temp_notification_audit_ids ON COMMIT DROP AS
    SELECT na.id
    FROM notification_audit na
    JOIN temp_notification_ids tn ON na.notification_id = tn.id;

    ALTER TABLE temp_notification_audit_ids ADD PRIMARY KEY (id);
    ANALYZE temp_notification_audit_ids;

    -- Create a temp table for webhook event IDs
    CREATE TEMP TABLE temp_webhook_event_ids ON COMMIT DROP AS
    SELECT w.event_id
    FROM webhook w
    JOIN temp_notification_audit_ids tna ON w.event_id = tna.id;

    ALTER TABLE temp_webhook_event_ids ADD PRIMARY KEY (event_id);
    ANALYZE temp_webhook_event_ids;

    -- Delete operations
    DELETE FROM webhook w USING temp_webhook_event_ids t WHERE w.event_id = t.event_id;
    DELETE FROM notification_audit na USING temp_notification_audit_ids t WHERE na.id = t.id;
    DELETE FROM notification n USING temp_notification_ids t WHERE n.id = t.id;
    DELETE FROM workflow_execution we USING temp_workflow_execution_ids t WHERE we.id = t.id;
    DELETE FROM workflow_request wr USING temp_workflow_request_ids t WHERE wr.id = t.id;

    DELETE FROM notification_stat WHERE created_at < archival_date;
    DELETE FROM workflow_stat WHERE created_at < archival_date;
END;
$procedure$;

-- DROP PROCEDURE public.cleanup_old_records_conductor(date);
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