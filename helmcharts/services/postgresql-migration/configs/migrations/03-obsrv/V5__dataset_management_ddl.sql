ALTER TABLE datasources
  ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL default 1,
  ADD COLUMN IF NOT EXISTS is_primary BOOLEAN,
  ADD COLUMN IF NOT EXISTS name TEXT;

UPDATE datasources SET is_primary = true, name = datasource;

ALTER TABLE connector_instances ADD COLUMN IF NOT EXISTS name TEXT;

ALTER TABLE oauth_users ADD COLUMN is_owner BOOLEAN DEFAULT FALSE;
UPDATE oauth_users SET is_owner=true WHERE user_name ='obsrv_admin';

UPDATE oauth_users SET roles='{admin}' WHERE user_name ='obsrv_admin';

ALTER TABLE oauth_users ADD COLUMN created_by TEXT DEFAULT 'SYSTEM';
ALTER TABLE oauth_users ADD COLUMN updated_by TEXT DEFAULT 'SYSTEM';

CREATE TABLE IF NOT EXISTS job_queue (
    id VARCHAR(255) PRIMARY KEY NOT NULL,  
    dataset_id VARCHAR(255) NOT NULL,  
    job_type VARCHAR(50) NOT NULL,  
    job_params JSONB NOT NULL,  
    status VARCHAR(20) NOT NULL CHECK (status IN ('submitted', 'approved', 'rejected', 'in_progress', 'completed', 'failed', 'cancelled')),  
    priority INTEGER DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),  
    progress DECIMAL(5,2) DEFAULT 0 CHECK (progress BETWEEN 0 AND 100),  
    resource_config JSONB DEFAULT '{}'::JSONB,  
    report JSONB DEFAULT '{}'::JSONB,  
    requested_by VARCHAR(255) DEFAULT 'SYSTEM',  
    approved_by VARCHAR(255) DEFAULT 'SYSTEM',  
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),  
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),  
    completed_at TIMESTAMP WITH TIME ZONE,  
    reviewed_at TIMESTAMP WITH TIME ZONE,  
    message TEXT DEFAULT '',  
    iteration INTEGER DEFAULT 0 CHECK (iteration BETWEEN 0 AND 3)  
);  

ALTER TABLE job_queue 
ADD CONSTRAINT job_queue_status_check 
CHECK (status IN ('submitted', 'approved', 'rejected', 'in_progress', 'completed', 'failed', 'cancelled', 'queued', 'partial_success'));

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO obsrv;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO obsrv;
