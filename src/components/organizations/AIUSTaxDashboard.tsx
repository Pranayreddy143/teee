import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, Building2, Brain, CheckCircle2, Clock, Users, AlertCircle } from 'lucide-react';
import { toast } from 'react-toastify';
import { supabase } from '../../supabaseClient';
import { useAuth } from '../../auth';
import CreateTicketModal from '../CreateTicketModal';
import NotificationBell from '../NotificationBell';

interface Organization {
  id: string;
  name: string;
  theme_primary_color: string;
  theme_secondary_color: string;
  theme_accent_color: string;
}

interface TicketStats {
  assigned: number;
  closed: number;
  open: number;
  inProgress: number;
}

interface Ticket {
  id: string;
  ticket_no: string;
  name_of_client: string;
  issue_type: string;
  status: string;
  created_on: string;
  assigned_to?: string;
}

interface User {
  id: string;
  email: string;
}

export default function AIUSTaxDashboard() {
  const { user, signOut } = useAuth();
  const navigate = useNavigate();
  const [selectedOrg, setSelectedOrg] = useState<Organization | null>(null);
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [users, setUsers] = useState<User[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [selectedTicket, setSelectedTicket] = useState<Ticket | null>(null);
  const [newAssignedTickets, setNewAssignedTickets] = useState<Ticket[]>([]);
  const [ticketStats, setTicketStats] = useState<TicketStats>({
    assigned: 0,
    closed: 0,
    open: 0,
    inProgress: 0
  });
  const [statusFilter, setStatusFilter] = useState('');

  useEffect(() => {
    const fetchOrganization = async () => {
      const { data, error } = await supabase
        .from('organizations')
        .select('*')
        .eq('slug', 'aius-tax')
        .single();

      if (error) {
        console.error('Error fetching organization:', error);
        navigate('/');
        return;
      }

      setSelectedOrg(data);
    };

    fetchOrganization();
  }, [navigate]);

  useEffect(() => {
    const fetchUsers = async () => {
      const { data, error } = await supabase.from('users').select('*');
      if (error) {
        console.error('Error fetching users:', error);
        return;
      }
      setUsers(data || []);
    };

    fetchUsers();
  }, []);

  useEffect(() => {
    if (selectedOrg && user) {
      fetchTickets();
      checkNewAssignedTickets();
    }
  }, [selectedOrg, searchQuery]);

  const fetchTicketStats = async () => {
    if (!selectedOrg) return;

    try {
      const [assigned, closed, open, inProgress] = await Promise.all([
        supabase
          .from('tickets')
          .select('*', { count: 'exact' })
          .eq('organization_id', selectedOrg.id)
          .not('assigned_to', 'is', null),
        supabase
          .from('tickets')
          .select('*', { count: 'exact' })
          .eq('organization_id', selectedOrg.id)
          .eq('status', 'closed'),
        supabase
          .from('tickets')
          .select('*', { count: 'exact' })
          .eq('organization_id', selectedOrg.id)
          .eq('status', 'open'),
        supabase
          .from('tickets')
          .select('*', { count: 'exact' })
          .eq('organization_id', selectedOrg.id)
          .eq('status', 'in_progress')
      ]);

      setTicketStats({
        assigned: assigned.count || 0,
        closed: closed.count || 0,
        open: open.count || 0,
        inProgress: inProgress.count || 0
      });
    } catch (error) {
      console.error('Error fetching ticket stats:', error);
    }
  };

  useEffect(() => {
    if (selectedOrg) {
      fetchTickets();
      fetchTicketStats();
    }
  }, [selectedOrg, searchQuery, statusFilter]);

  const fetchTickets = async () => {
    try {
      let query = supabase
        .from('tickets')
        .select('*')
        .eq('organization_id', selectedOrg?.id)
        .order('created_on', { ascending: false });

      if (searchQuery.trim()) {
        query = query.or(
          `mobile_no.ilike.%${searchQuery}%,` +
          `client_file_no.ilike.%${searchQuery}%,` +
          `name_of_client.ilike.%${searchQuery}%,` +
          `ticket_no.ilike.%${searchQuery}%`
        );
      }

      if (statusFilter) {
        query = query.eq('status', statusFilter);
      }

      const { data, error } = await query;
      if (error) throw error;
      setTickets(data || []);
    } catch (error) {
      console.error('Error fetching tickets:', error);
      toast.error('Error fetching tickets');
    }
  };

  const checkNewAssignedTickets = async () => {
    try {
      const { data, error } = await supabase
        .from('tickets')
        .select('*')
        .eq('assigned_to', user?.id)
        .eq('status', 'open');

      if (error) throw error;

      if (data && data.length > 0) {
        setNewAssignedTickets(data);
      }
    } catch (error) {
      console.error('Error checking new assigned tickets:', error);
    }
  };

  const handleChangeOrg = () => {
    navigate('/');
  };

  const handleTicketClick = (ticket: Ticket) => {
    setSelectedTicket(ticket);
    setIsCreateModalOpen(true);
  };

  const handleStatusClick = (status: string) => {
    setStatusFilter(status === statusFilter ? '' : status);
  };

  if (!selectedOrg) return null;

  const headerStyle = {
    background: `linear-gradient(135deg, ${selectedOrg.theme_primary_color}, ${selectedOrg.theme_secondary_color})`,
  };

  const accentStyle = {
    backgroundColor: selectedOrg.theme_accent_color,
  };

  return (
    <div className="min-h-screen bg-gray-100">
      <header className="shadow" style={headerStyle}>
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center">
              <Brain className="w-12 h-12 text-white mr-4" />
              <div>
                <div className="text-2xl font-bold text-white">AIUSTax</div>
                <div className="text-sm text-white opacity-90">Help Desk Manager</div>
              </div>
            </div>
            <div className="flex items-center space-x-4">
              <NotificationBell notifications={newAssignedTickets} setNotifications={setNewAssignedTickets} />
              <button
                onClick={handleChangeOrg}
                className="p-2 text-white rounded-full hover:bg-white/10"
                title="Change Organization"
              >
                <Building2 className="w-6 h-6" />
              </button>
              <span className="text-sm text-white">
                {user?.email}
              </span>
              <button
                onClick={() => signOut()}
                className="px-4 py-2 rounded text-white border border-white/30 hover:bg-white/10"
              >
                Sign Out
              </button>
            </div>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <div 
            className={`bg-white p-6 rounded-lg shadow hover:shadow-md transition-shadow cursor-pointer ${
              statusFilter === '' ? 'ring-2 ring-blue-500' : ''
            }`}
            onClick={() => handleStatusClick('assigned')}
          >
            <div className="flex items-center justify-between">
              <div>
                <div className="text-sm text-gray-500">Assigned Tickets</div>
                <div className="text-2xl font-bold mt-2">{ticketStats.assigned}</div>
              </div>
              <Users className="w-8 h-8 text-blue-500" />
            </div>
          </div>

          <div 
            className={`bg-white p-6 rounded-lg shadow hover:shadow-md transition-shadow cursor-pointer ${
              statusFilter === 'closed' ? 'ring-2 ring-green-500' : ''
            }`}
            onClick={() => handleStatusClick('closed')}
          >
            <div className="flex items-center justify-between">
              <div>
                <div className="text-sm text-gray-500">Closed Tickets</div>
                <div className="text-2xl font-bold mt-2">{ticketStats.closed}</div>
              </div>
              <CheckCircle2 className="w-8 h-8 text-green-500" />
            </div>
          </div>

          <div 
            className={`bg-white p-6 rounded-lg shadow hover:shadow-md transition-shadow cursor-pointer ${
              statusFilter === 'open' ? 'ring-2 ring-red-500' : ''
            }`}
            onClick={() => handleStatusClick('open')}
          >
            <div className="flex items-center justify-between">
              <div>
                <div className="text-sm text-gray-500">Open Tickets</div>
                <div className="text-2xl font-bold mt-2">{ticketStats.open}</div>
              </div>
              <AlertCircle className="w-8 h-8 text-red-500" />
            </div>
          </div>

          <div 
            className={`bg-white p-6 rounded-lg shadow hover:shadow-md transition-shadow cursor-pointer ${
              statusFilter === 'in_progress' ? 'ring-2 ring-yellow-500' : ''
            }`}
            onClick={() => handleStatusClick('in_progress')}
          >
            <div className="flex items-center justify-between">
              <div>
                <div className="text-sm text-gray-500">In Progress</div>
                <div className="text-2xl font-bold mt-2">{ticketStats.inProgress}</div>
              </div>
              <Clock className="w-8 h-8 text-yellow-500" />
            </div>
          </div>
        </div>

        <div className="bg-white shadow rounded-lg p-6">
          <div className="flex justify-between items-center mb-6">
            <button 
              className="px-4 py-2 rounded text-white"
              style={accentStyle}
              onClick={() => setIsCreateModalOpen(true)}
            >
              Raise new ticket
            </button>
            <div className="flex items-center space-x-4">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" />
                <input
                  type="text"
                  placeholder="Search tickets..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-10 pr-4 py-2 border rounded-md w-96"
                />
              </div>
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="bg-gray-50">
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Ticket No
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Client
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Issue Type
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Assigned To
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Created
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {tickets.map((ticket: Ticket) => (
                  <tr 
                    key={ticket.id} 
                    className="hover:bg-gray-50 cursor-pointer"
                    onClick={() => handleTicketClick(ticket)}
                  >
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      {ticket.ticket_no}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {ticket.name_of_client}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {ticket.issue_type}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {ticket.assigned_to ? users.find(u => u.id === ticket.assigned_to)?.email || 'Unknown' : 'Unassigned'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span
                        className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full"
                        style={{
                          backgroundColor: selectedOrg.theme_accent_color + '20',
                          color: selectedOrg.theme_accent_color
                        }}
                      >
                        {ticket.status}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {new Date(ticket.created_on).toLocaleDateString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </main>

      <CreateTicketModal
        isOpen={isCreateModalOpen}
        onClose={() => {
          setIsCreateModalOpen(false);
          setSelectedTicket(null);
        }}
        organizationId={selectedOrg.id}
        onTicketCreated={fetchTickets}
        ticket={selectedTicket}
      />
    </div>
  );
}