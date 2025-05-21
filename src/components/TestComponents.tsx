import React, { useState } from 'react';
import { X, AlertCircle } from 'lucide-react';
import CreateTicketModal from './CreateTicketModal';
import { Login } from '../Login';
import OrganizationSelect from './OrganizationSelect';

export default function TestComponents() {
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);

  const testOrg = {
    id: 'test-org',
    name: 'Test Organization',
    theme_primary_color: '#1a365d',
    theme_secondary_color: '#2d3748',
    theme_accent_color: '#4299e1',
  };

  return (
    <div className="min-h-screen bg-gray-100 p-8">
      <div className="max-w-7xl mx-auto">
        <h1 className="text-3xl font-bold mb-8">Component Testing Area</h1>

        <div className="space-y-12">
          {/* CreateTicketModal Test */}
          <section className="bg-white p-6 rounded-lg shadow">
            <h2 className="text-xl font-semibold mb-4">CreateTicketModal</h2>
            <button
              onClick={() => setIsCreateModalOpen(true)}
              className="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
            >
              Open Create Ticket Modal
            </button>
            <CreateTicketModal
              isOpen={isCreateModalOpen}
              onClose={() => setIsCreateModalOpen(false)}
              organizationId={testOrg.id}
              onTicketCreated={() => console.log('Ticket created')}
            />
          </section>

          {/* Login Component Test */}
          <section className="bg-white p-6 rounded-lg shadow">
            <h2 className="text-xl font-semibold mb-4">Login Component</h2>
            <div className="border rounded-lg p-4">
              <Login />
            </div>
          </section>

          {/* Organization Select Test */}
          <section className="bg-white p-6 rounded-lg shadow">
            <h2 className="text-xl font-semibold mb-4">Organization Select</h2>
            <div className="border rounded-lg p-4">
              <OrganizationSelect />
            </div>
          </section>
        </div>
      </div>
    </div>
  );
}
