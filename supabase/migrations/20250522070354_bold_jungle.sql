-- Drop existing policies
DROP POLICY IF EXISTS "Users can update their own profile" ON users;
DROP POLICY IF EXISTS "Users can view organizations they belong to" ON organizations;
DROP POLICY IF EXISTS "Users can view their organizations" ON user_organizations;
DROP POLICY IF EXISTS "Users can access tickets in their organizations" ON tickets;
DROP POLICY IF EXISTS "Users can view participants in their rooms" ON chat_participants;
DROP POLICY IF EXISTS "Users can join rooms they are invited to" ON chat_participants;
DROP POLICY IF EXISTS "Users can view messages in their rooms" ON chat_messages;
DROP POLICY IF EXISTS "Users can send messages to their rooms" ON chat_messages;
DROP POLICY IF EXISTS "Users can edit their own messages" ON chat_messages;
DROP POLICY IF EXISTS "Users can view attachments in their rooms" ON chat_attachments;
DROP POLICY IF EXISTS "Users can upload attachments to their messages" ON chat_attachments;

-- Recreate policies with optimized auth checks
CREATE POLICY "Users can update their own profile"
  ON users FOR UPDATE
  TO authenticated
  USING (id = (SELECT auth.uid()))
  WITH CHECK (id = (SELECT auth.uid()));

CREATE POLICY "Users can view organizations they belong to"
  ON organizations
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_organizations
      WHERE organization_id = organizations.id
      AND user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY "Users can view their organizations"
  ON user_organizations
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY "Users can access tickets in their organizations"
  ON tickets
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_organizations
      WHERE user_id = (SELECT auth.uid())
      AND organization_id = tickets.organization_id
    )
  );

-- Chat room policies
CREATE POLICY "Users can view rooms they are participants in"
  ON chat_rooms
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM chat_participants
      WHERE room_id = chat_rooms.id
      AND user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY "Users can create rooms"
  ON chat_rooms
  FOR INSERT
  TO authenticated
  WITH CHECK (created_by = (SELECT auth.uid()));

-- Chat participant policies
CREATE POLICY "Users can view participants in their rooms"
  ON chat_participants
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM chat_participants AS cp
      WHERE cp.room_id = chat_participants.room_id
      AND cp.user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY "Users can join rooms they are invited to"
  ON chat_participants
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid()) OR
    EXISTS (
      SELECT 1 FROM chat_participants
      WHERE room_id = chat_participants.room_id
      AND user_id = (SELECT auth.uid())
      AND role = 'admin'
    )
  );

-- Chat message policies
CREATE POLICY "Users can view messages in their rooms"
  ON chat_messages
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM chat_participants
      WHERE room_id = chat_messages.room_id
      AND user_id = (SELECT auth.uid())
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
      AND user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY "Users can edit their own messages"
  ON chat_messages
  FOR UPDATE
  TO authenticated
  USING (sender_id = (SELECT auth.uid()))
  WITH CHECK (sender_id = (SELECT auth.uid()));

-- Chat attachment policies
CREATE POLICY "Users can view attachments in their rooms"
  ON chat_attachments
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM chat_messages
      JOIN chat_participants ON chat_messages.room_id = chat_participants.room_id
      WHERE chat_messages.id = chat_attachments.message_id
      AND chat_participants.user_id = (SELECT auth.uid())
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
      AND sender_id = (SELECT auth.uid())
    )
  );

-- Drop duplicate policies
DROP POLICY IF EXISTS "Allow public read access" ON tickets;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON tickets;
DROP POLICY IF EXISTS "Allow public insert access" ON tickets;
DROP POLICY IF EXISTS "Enable insert access for authenticated users" ON tickets;
DROP POLICY IF EXISTS "Allow public update access" ON tickets;
DROP POLICY IF EXISTS "Enable update access for authenticated users" ON tickets;
DROP POLICY IF EXISTS "Allow public delete access" ON tickets;
DROP POLICY IF EXISTS "Enable delete access for authenticated users" ON tickets;

DROP POLICY IF EXISTS "Anyone can view organizations" ON organizations;
DROP POLICY IF EXISTS "System can create users" ON users;
DROP POLICY IF EXISTS "Allow authenticated users to view users" ON users;
DROP POLICY IF EXISTS "Allow system to create users" ON users;