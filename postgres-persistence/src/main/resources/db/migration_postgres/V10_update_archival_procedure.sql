
CREATE TABLE IF NOT EXISTS archival_logs (
    id SERIAL PRIMARY KEY,
    log_time TIMESTAMP NOT NULL DEFAULT now(),
    log_message TEXT NOT NULL,
    archival_date DATE NOT NULL
);

CREATE OR REPLACE PROCEDURE public.conductor_archive(IN archival_date date)
 LANGUAGE plpgsql
AS $procedure$
DECLARE
    deleted_workflows INT := 0;
    deleted_wf_def_links INT := 0;
    deleted_wf_to_task INT := 0;
    deleted_tasks INT := 0;
    deleted_task_scheduled INT := 0;
    total_deleted INT := 0;
    log_message TEXT;
BEGIN
    -- Step 1: Collect workflow IDs eligible for deletion
    CREATE TEMP TABLE temp_workflows_to_delete ON COMMIT DROP AS
    SELECT workflow_id
    FROM workflow
    WHERE created_on < archival_date
      AND (json_data::jsonb ->> 'status') = 'COMPLETED';

    ALTER TABLE temp_workflows_to_delete ADD PRIMARY KEY (workflow_id);
    ANALYZE temp_workflows_to_delete;

    -- Step 2: Cascade deletes

    -- workflow_def_to_workflow
    DELETE FROM workflow_def_to_workflow wdw
    USING temp_workflows_to_delete tw
    WHERE wdw.workflow_id = tw.workflow_id;
    GET DIAGNOSTICS deleted_wf_def_links = ROW_COUNT;

    -- workflow_to_task
    CREATE TEMP TABLE temp_tasks_to_delete ON COMMIT DROP AS
    SELECT wt.task_id
    FROM workflow_to_task wt
    JOIN temp_workflows_to_delete tw ON wt.workflow_id = tw.workflow_id;
    
    ALTER TABLE temp_tasks_to_delete ADD PRIMARY KEY (task_id);
    ANALYZE temp_tasks_to_delete;

    DELETE FROM workflow_to_task wt
    USING temp_workflows_to_delete tw
    WHERE wt.workflow_id = tw.workflow_id;
    GET DIAGNOSTICS deleted_wf_to_task = ROW_COUNT;

    -- task_scheduled
    DELETE FROM task_scheduled ts
    USING temp_tasks_to_delete tt
    WHERE ts.task_id = tt.task_id;
    GET DIAGNOSTICS deleted_task_scheduled = ROW_COUNT;

    -- task
    DELETE FROM task t
    USING temp_tasks_to_delete tt
    WHERE t.task_id = tt.task_id;
    GET DIAGNOSTICS deleted_tasks = ROW_COUNT;

    -- workflow
    DELETE FROM workflow w
    USING temp_workflows_to_delete tw
    WHERE w.workflow_id = tw.workflow_id;
    GET DIAGNOSTICS deleted_workflows = ROW_COUNT;

    -- Step 3: Logging
    total_deleted := deleted_workflows + deleted_wf_def_links +
                     deleted_wf_to_task + deleted_tasks + deleted_task_scheduled;

    log_message := 'Cleanup completed successfully for COMPLETED workflows before ' || archival_date || '. ' ||
                   'Total deleted: ' || total_deleted || ' | Breakdown: ' ||
                   'workflow: ' || deleted_workflows || ', ' ||
                   'workflow_def_to_workflow: ' || deleted_wf_def_links || ', ' ||
                   'workflow_to_task: ' || deleted_wf_to_task || ', ' ||
                   'task: ' || deleted_tasks || ', ' ||
                   'task_scheduled: ' || deleted_task_scheduled;

    INSERT INTO archival_logs(log_message, archival_date)
    VALUES (log_message, archival_date);

EXCEPTION
    WHEN OTHERS THEN
        INSERT INTO archival_logs(log_message, archival_date)
        VALUES ('Error in cleanup_completed_workflows: ' || SQLERRM, archival_date);
        RAISE;
END;
$procedure$
;