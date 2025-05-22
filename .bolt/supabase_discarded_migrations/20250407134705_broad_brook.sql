/*
  # Remove chat functionality

  1. Changes
    - Drop all chat-related tables and their dependencies
    - Remove associated triggers and functions
    - Clean up any remaining chat-related objects

  2. Security
    - Remove all chat-related policies
*/

-- Drop chat-related tables with CASCADE to handle dependencies
DROP TABLE IF EXISTS chat_attachments CASCADE;
DROP TABLE IF EXISTS chat_messages CASCADE;
DROP TABLE IF EXISTS chat_participants CASCADE;
DROP TABLE IF EXISTS chat_rooms CASCADE;

-- Drop any remaining chat-related functions
DROP FUNCTION IF EXISTS update_room_timestamp() CASCADE;