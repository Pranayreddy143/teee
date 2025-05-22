import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://xyubweqwahtaeiazakbs.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh5dWJ3ZXF3YWh0YWVpYXpha2JzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4OTQ5NTksImV4cCI6MjA2MzQ3MDk1OX0.Jd_EQiZyQNCdQdknp9zUDEFQwh2iBPqxbYQETRR5L7g';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);