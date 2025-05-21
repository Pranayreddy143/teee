/*
  # Remove chat functionality

  1. Changes
    - Drop all chat-related tables and their dependencies
    - Remove associated triggers, functions, and policies
    - Use CASCADE to ensure all dependent objects are removed

  2. Security
    - Clean up all related policies
*/

-- First drop all policies to avoid dependency issues
DROP POLICY IF EXISTS "Users can view rooms they are participants in" ON chat_rooms;
DROP POLICY IF EXISTS "Users can create rooms" ON chat_rooms;
DROP POLICY IF EXISTS "Users can view participants in their rooms" ON chat_participants;
DROP POLICY IF EXISTS "Users can join rooms they are invited to" ON chat_participants;
DROP POLICY IF EXISTS "Users can view messages in their rooms" ON chat_messages;
DROP POLICY IF EXISTS "Users can send messages to their rooms" ON chat_messages;
DROP POLICY IF EXISTS "Users can edit their own messages" ON chat_messages;
DROP POLICY IF EXISTS "Users can view attachments in their rooms" ON chat_attachments;
DROP POLICY IF EXISTS "Users can upload attachments to their messages" ON chat_attachments;

-- Drop trigger first
DROP TRIGGER IF EXISTS update_room_timestamp_on_message ON chat_messages;

-- Drop function
DROP FUNCTION IF EXISTS update_room_timestamp();

-- Drop tables with CASCADE to handle dependencies
DROP TABLE IF EXISTS chat_attachments CASCADE;
DROP TABLE IF EXISTS chat_messages CASCADE;
DROP TABLE IF EXISTS chat_participants CASCADE;
DROP TABLE IF EXISTS chat_rooms CASCADE;