export interface Organization {
  id: string;
  name: string;
  slug: string;
  theme_primary_color: string;
  theme_secondary_color: string;
  theme_accent_color: string;
  logo_url?: string;
}

export interface UserOrganization {
  user_id: string;
  organization_id: string;
  role: 'admin' | 'member';
  organizations?: Organization;
}
