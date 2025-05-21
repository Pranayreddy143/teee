export type Json = string | number | boolean | null | { [key: string]: Json } | Json[]

export interface Database {
  public: {
    Tables: {
      tickets: {
        Row: {
          id: string
          created_at: string | null
          updated_at: string | null
          title: string
          description: string | null
          status: string
          priority: string
          user_id: string | null
          attachment_url: string | null
          attachment_name: string | null
          attachment_size: number | null
          assigned_to: string | null
        }
        Insert: {
          id?: string
          created_at?: string | null
          updated_at?: string | null
          title: string
          description?: string | null
          status: string
          priority: string
          user_id?: string | null
          attachment_url?: string | null
          attachment_name?: string | null
          attachment_size?: number | null
          assigned_to?: string | null
        }
        Update: {
          id?: string
          created_at?: string | null
          updated_at?: string | null
          title?: string
          description?: string | null
          status?: string
          priority?: string
          user_id?: string | null
          attachment_url?: string | null
          attachment_name?: string | null
          attachment_size?: number | null
          assigned_to?: string | null
        }
      }
      users: {
        Row: {
          id: string
          created_at: string | null
          updated_at: string | null
          email: string
          name: string | null
        }
        Insert: {
          id?: string
          created_at?: string | null
          updated_at?: string | null
          email: string
          name?: string | null
        }
        Update: {
          id?: string
          created_at?: string | null
          updated_at?: string | null
          email?: string
          name?: string | null
        }
      }
    }
    Views: {}
    Functions: {}
    Enums: {}
    CompositeTypes: {}
  }
}