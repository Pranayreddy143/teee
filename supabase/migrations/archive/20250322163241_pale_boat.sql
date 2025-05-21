/*
  # Add chat messenger system

  1. New Tables
    - `chat_rooms`
      - For group chats and direct messages
      - Tracks room type, name, and creation info
    
    - `chat_participants`
      - Links users to chat rooms
      - Tracks participant roles and status
    
    - `chat_messages`
      - Stores all messages
      - Supports text, files, and documents
    
    - `chat_attachments`
      - Stores file metadata
      - Links to Storage bucket

  2. Security
    - Enable RLS on all tables
    - Add policies for proper access control
    - Ensure participants can only access their rooms
*/

-- Chat Rooms Table
CREATE TABLE IF NOT EXISTS chat_rooms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text,
  type text NOT NULL CHECK (type IN ('direct', 'group')),
  created_by uuid REFERENCES auth.users(id) NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Chat Participants Table
CREATE TABLE IF NOT EXISTS chat_participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid REFERENCES chat_rooms(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES auth.users(id) NOT NULL,
  role text DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  joined_at timestamptz DEFAULT now(),
  last_read_at timestamptz DEFAULT now(),
  UNIQUE(room_id, user_id)
);

-- Chat Messages Table
CREATE TABLE IF NOT EXISTS chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid REFERENCES chat_rooms(id) ON DELETE CASCADE NOT NULL,
  sender_id uuid REFERENCES auth.users(id) NOT NULL,
  message_type text NOT NULL CHECK (message_type IN ('text', 'file', 'document')),
  content text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  is_edited boolean DEFAULT false
);

-- Chat Attachments Table
CREATE TABLE IF NOT EXISTS chat_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid REFERENCES chat_messages(id) ON DELETE CASCADE NOT NULL,
  file_name text NOT NULL,
  file_size bigint NOT NULL,
  file_type text NOT NULL,
  storage_path text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_attachments ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$ 
BEGIN
    -- chat_rooms policies
    DROP POLICY IF EXISTS "Users can view rooms they are participants in" ON chat_rooms;
    DROP POLICY IF EXISTS "Users can create rooms" ON chat_rooms;
    
    -- chat_participants policies
    DROP POLICY IF EXISTS "Users can view participants in their rooms" ON chat_participants;
    DROP POLICY IF EXISTS "Users can join rooms they are invited to" ON chat_participants;
    
    -- chat_messages policies
    DROP POLICY IF EXISTS "Users can view messages in their rooms" ON chat_messages;
    DROP POLICY IF EXISTS "Users can send messages to their rooms" ON chat_messages;
    DROP POLICY IF EXISTS "Users can edit their own messages" ON chat_messages;
    
    -- chat_attachments policies
    DROP POLICY IF EXISTS "Users can view attachments in their rooms" ON chat_attachments;
    DROP POLICY IF EXISTS "Users can upload attachments to their messages" ON chat_attachments;
END $$;

-- Policies for chat_rooms
CREATE POLICY "Users can view rooms they are participants in"
  ON chat_rooms
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM chat_participants
      WHERE room_id = chat_rooms.id
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create rooms"
  ON chat_rooms
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = created_by);

-- Policies for chat_participants
CREATE POLICY "Users can view participants in their rooms"
  ON chat_participants
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM chat_participants AS cp
      WHERE cp.room_id = chat_participants.room_id
      AND cp.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can join rooms they are invited to"
  ON chat_participants
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM chat_participants
      WHERE room_id = chat_participants.room_id
      AND user_id = auth.uid()
      AND role = 'admin'
    )
  );

-- Policies for chat_messages
CREATE POLICY "Users can view messages in their rooms"
  ON chat_messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM chat_participants
      WHERE room_id = chat_messages.room_id
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "Users can send messages to their rooms"
  ON chat_messages
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM chat_participants
      WHERE room_id = chat_messages.room_id
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "Users can edit their own messages"
  ON chat_messages
  FOR UPDATE
  TO authenticated
  USING (sender_id = auth.uid())
  WITH CHECK (sender_id = auth.uid());

-- Policies for chat_attachments
CREATE POLICY "Users can view attachments in their rooms"
  ON chat_attachments
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM chat_messages
      JOIN chat_participants ON chat_messages.room_id = chat_participants.room_id
      WHERE chat_messages.id = chat_attachments.message_id
      AND chat_participants.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can upload attachments to their messages"
  ON chat_attachments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM chat_messages
      WHERE id = message_id
      AND sender_id = auth.uid()
    )
  );

-- Drop existing function and trigger if they exist
DROP TRIGGER IF EXISTS update_room_timestamp_on_message ON chat_messages;
DROP FUNCTION IF EXISTS update_room_timestamp();

-- Function to update room's updated_at timestamp
CREATE OR REPLACE FUNCTION update_room_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE chat_rooms
  SET updated_at = now()
  WHERE id = NEW.room_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update room timestamp on new message
CREATE TRIGGER update_room_timestamp_on_message
  AFTER INSERT ON chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_room_timestamp();