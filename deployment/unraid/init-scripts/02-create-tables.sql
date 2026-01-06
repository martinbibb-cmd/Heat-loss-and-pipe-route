-- ============================================================================
-- Heating Design Core Tables
-- ============================================================================
-- Note: In production, Prisma migrations will manage the schema
-- This file provides the reference schema structure

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    company_name VARCHAR(255),
    role VARCHAR(50) DEFAULT 'user',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Projects table
CREATE TABLE IF NOT EXISTS projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    address TEXT,
    client_name VARCHAR(255),
    client_email VARCHAR(255),
    status project_status DEFAULT 'draft',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Floor plans table
CREATE TABLE IF NOT EXISTS floor_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    floor_level INTEGER DEFAULT 0,
    file_url TEXT,
    file_size INTEGER,
    file_type VARCHAR(50),
    scale_factor DECIMAL(10,4),
    dimensions JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Rooms table
CREATE TABLE IF NOT EXISTS rooms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    floor_plan_id UUID REFERENCES floor_plans(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    room_type room_type DEFAULT 'other',
    area DECIMAL(10,2),
    volume DECIMAL(10,2),
    ceiling_height DECIMAL(5,2),
    exterior_walls INTEGER DEFAULT 0,
    window_area DECIMAL(10,2) DEFAULT 0,
    door_count INTEGER DEFAULT 0,
    target_temperature DECIMAL(4,1) DEFAULT 20.0,
    coordinates JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Heat loss calculations table
CREATE TABLE IF NOT EXISTS heat_calculations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
    calculation_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    status calculation_status DEFAULT 'pending',

    -- Input parameters
    outdoor_temp DECIMAL(4,1),
    indoor_temp DECIMAL(4,1),
    wall_u_value DECIMAL(6,4),
    window_u_value DECIMAL(6,4),
    floor_u_value DECIMAL(6,4),
    ceiling_u_value DECIMAL(6,4),
    air_change_rate DECIMAL(4,2),

    -- Calculation results
    transmission_loss DECIMAL(10,2),
    ventilation_loss DECIMAL(10,2),
    total_heat_loss DECIMAL(10,2),
    safety_factor DECIMAL(4,2) DEFAULT 1.15,
    design_heat_load DECIMAL(10,2),

    -- Metadata
    calculation_method VARCHAR(100),
    calculation_time_ms INTEGER,
    error_message TEXT,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Radiators/heating units table
CREATE TABLE IF NOT EXISTS heating_units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
    heat_calculation_id UUID REFERENCES heat_calculations(id),

    unit_type VARCHAR(50),
    manufacturer VARCHAR(255),
    model VARCHAR(255),
    output_watts DECIMAL(10,2),
    flow_temp DECIMAL(4,1),
    return_temp DECIMAL(4,1),

    position JSONB,
    dimensions JSONB,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Pipe routes table
CREATE TABLE IF NOT EXISTS pipe_routes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    name VARCHAR(255),
    pipe_diameter INTEGER,
    material VARCHAR(100),
    insulation_thickness INTEGER,
    route_coordinates JSONB,
    total_length DECIMAL(10,2),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Reports/exports table
CREATE TABLE IF NOT EXISTS exports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    export_type VARCHAR(50),
    file_url TEXT,
    file_size INTEGER,
    format VARCHAR(20),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- API keys for external integrations (Atlas)
CREATE TABLE IF NOT EXISTS api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    key_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    last_used_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT true,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_projects_user_id ON projects(user_id);
CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);
CREATE INDEX IF NOT EXISTS idx_floor_plans_project_id ON floor_plans(project_id);
CREATE INDEX IF NOT EXISTS idx_rooms_floor_plan_id ON rooms(floor_plan_id);
CREATE INDEX IF NOT EXISTS idx_heat_calc_room_id ON heat_calculations(room_id);
CREATE INDEX IF NOT EXISTS idx_heat_calc_status ON heat_calculations(status);
CREATE INDEX IF NOT EXISTS idx_heating_units_room_id ON heating_units(room_id);
CREATE INDEX IF NOT EXISTS idx_pipe_routes_project_id ON pipe_routes(project_id);
CREATE INDEX IF NOT EXISTS idx_exports_project_id ON exports(project_id);

-- Create full-text search indexes
CREATE INDEX IF NOT EXISTS idx_projects_search ON projects USING gin(to_tsvector('english', name || ' ' || COALESCE(description, '')));
CREATE INDEX IF NOT EXISTS idx_rooms_search ON rooms USING gin(to_tsvector('english', name));

-- Add updated_at triggers
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON projects FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_floor_plans_updated_at BEFORE UPDATE ON floor_plans FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_rooms_updated_at BEFORE UPDATE ON rooms FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_heat_calc_updated_at BEFORE UPDATE ON heat_calculations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO heating_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO heating_admin;

-- Log completion
DO $$
BEGIN
    RAISE NOTICE 'Core tables created successfully';
END $$;
