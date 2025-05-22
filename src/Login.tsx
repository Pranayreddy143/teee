import React, { useState, useEffect } from 'react';
import { useAuth } from './auth';
import { Headphones } from 'lucide-react';
import { supabase } from './supabaseClient';
import { useNavigate } from 'react-router-dom';

interface Organization {
  id: string;
  name: string;
  slug: string;
  theme_primary_color: string;
  theme_secondary_color: string;
  theme_accent_color: string;
}

export function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [organizations, setOrganizations] = useState<Organization[]>([]);
  const [selectedOrg, setSelectedOrg] = useState<string>('');
  const [error, setError] = useState<string>('');
  const [isLoadingOrgs, setIsLoadingOrgs] = useState(true);
  const { signIn } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    fetchOrganizations();
  }, []);

  const fetchOrganizations = async () => {
    setIsLoadingOrgs(true);
    setError('');
    
    try {
      const { data, error } = await supabase
        .from('organizations')
        .select('*')
        .order('name');

      if (error) {
        console.error('Supabase error:', error);
        setError('Failed to load organizations. Please try again later.');
        return;
      }

      if (!data || data.length === 0) {
        setError('No organizations found. Please contact your administrator.');
        return;
      }

      setOrganizations(data);
      // Only set selected org if none is selected yet
      if (!selectedOrg && data.length > 0) {
        setSelectedOrg(data[0].id);
      }
    } catch (error) {
      console.error('Error fetching organizations:', error);
      setError('Failed to load organizations. Please try again later.');
    } finally {
      setIsLoadingOrgs(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedOrg) {
      setError('Please select an organization');
      return;
    }
    
    setIsLoading(true);
    setError('');

    try {
      await signIn(email, password);
      const selectedOrgData = organizations.find(org => org.id === selectedOrg);
      if (selectedOrgData) {
        localStorage.setItem('selectedOrganization', JSON.stringify(selectedOrgData));
        navigate(`/${selectedOrgData.slug}`);
      }
    } catch (error: any) {
      console.error('Error signing in:', error);
      setError(error?.message || 'Invalid email or password');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full space-y-8">
        <div>
          <Headphones className="mx-auto h-12 w-12 text-blue-600" />
          <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
            Sign in to your account
          </h2>
          <p className="mt-2 text-center text-sm text-gray-600">
            Enter your credentials to access the help desk
          </p>
        </div>
        
        {error && (
          <div className="bg-red-50 border border-red-200 text-red-600 px-4 py-3 rounded-md">
            {error}
          </div>
        )}

        <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
          <div className="rounded-md shadow-sm -space-y-px">
            <div>
              <label htmlFor="email-address" className="sr-only">
                Email address
              </label>
              <input
                id="email-address"
                name="email"
                type="email"
                autoComplete="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-t-md focus:outline-none focus:ring-blue-500 focus:border-blue-500 focus:z-10 sm:text-sm"
                placeholder="Email address"
              />
            </div>
            <div>
              <label htmlFor="password" className="sr-only">
                Password
              </label>
              <input
                id="password"
                name="password"
                type="password"
                autoComplete="current-password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-b-md focus:outline-none focus:ring-blue-500 focus:border-blue-500 focus:z-10 sm:text-sm"
                placeholder="Password"
              />
            </div>
          </div>

          <div className="space-y-2">
            <label htmlFor="organization" className="block text-sm font-medium text-gray-700">
              Organization
            </label>
            <select
              id="organization"
              name="organization"
              value={selectedOrg}
              onChange={(e) => setSelectedOrg(e.target.value)}
              className="block w-full px-3 py-2 text-base border border-gray-300 bg-white rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 sm:text-sm disabled:bg-gray-100 disabled:cursor-not-allowed"
              disabled={isLoadingOrgs}
            >
              <option value="">Select an organization</option>
              {organizations.map(org => (
                <option key={org.id} value={org.id}>
                  {org.name}
                </option>
              ))}
            </select>
            {isLoadingOrgs && (
              <p className="mt-1 text-sm text-gray-500">Loading organizations...</p>
            )}
          </div>

          <div>
            <button
              type="submit"
              disabled={isLoading || isLoadingOrgs || !selectedOrg}
              className="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isLoading ? (
                <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
              ) : (
                'Sign in'
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}