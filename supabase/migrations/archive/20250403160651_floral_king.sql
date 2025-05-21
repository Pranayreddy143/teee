/*
  # Remove chat functionality

  1. Changes
    - Drop all chat-related tables and their dependencies
    - Remove associated triggers, functions, and policies
    - Use CASCADE to ensure all dependent objects are removed

  2. Security
    - Clean up all related policies
*/

-- Drop tables with CASCADE to handle dependencies
DROP TABLE IF EXISTS chat_rooms CASCADE;
DROP TABLE IF EXISTS chat_participants CASCADE;
DROP TABLE IF EXISTS chat_messages CASCADE;
DROP TABLE IF EXISTS chat_attachments CASCADE;

-- Drop function if it still exists
DROP FUNCTION IF EXISTS update_room_timestamp() CASCADE;