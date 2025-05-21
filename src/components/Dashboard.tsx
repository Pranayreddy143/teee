import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, Building2, Brain } from 'lucide-react';
import { toast } from 'react-toastify';
import { supabase } from '../supabaseClient';
import { useAuth } from '../auth';
import CreateTicketModal from './CreateTicketModal';
import NotificationBell from './NotificationBell';

interface Organization {
  id: string;
  name: string;
  theme_primary_color: string;
  theme_secondary_color: string;
  theme_accent_color: string;
}

interface DashboardStats {
  totalTickets: number;
  openTickets: number;
  resolvedToday: number;
  avgResponseTime: number;
}

interface Ticket {
  id: string;
  ticket_no: string;
  created_on: string;
  name_of_client: string;
  issue_type: string;
  status: string;
  assigned_to: string | null;
}

interface User {
  id: string;
  email: string;
}

export default function Dashboard() {
  const { user, signOut } = useAuth();
  const navigate = useNavigate();
  const [selectedOrg, setSelectedOrg] = useState<Organization | null>(null);
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [stats, setStats] = useState<DashboardStats>({
    totalTickets: 0,
    openTickets: 0,
    resolvedToday: 0,
    avgResponseTime: 0
  });
  const [newAssignedTickets, setNewAssignedTickets] = useState<Ticket[]>([]);
  const [selectedTicket, setSelectedTicket] = useState<Ticket | null>(null);
  const [users, setUsers] = useState<User[]>([]);

  useEffect(() => {
    const org = localStorage.getItem('selectedOrganization');
    if (!org) {
      navigate('/');
      return;
    }
    setSelectedOrg(JSON.parse(org));
  }, [navigate]);

  useEffect(() => {
    if (selectedOrg) {
      fetchTickets();
      fetchDashboardStats();
      checkNewAssignedTickets();
      fetchUsers();
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

  const fetchDashboardStats = async () => {
    try {
      const { data, error } = await supabase.rpc('get_dashboard_stats', {
        p_organization_id: selectedOrg?.id
      });
      
      if (error) throw error;
      setStats(data);
    } catch (error) {
      console.error('Error fetching stats:', error);
      toast.error('Failed to load dashboard statistics');
    }
  };

  const checkNewAssignedTickets = async () => {
    try {
      const { data, error } = await supabase
        .from('tickets')
        .select('*')
        .eq('assigned_to', user?.id)
        .eq('status', 'new');

      if (error) throw error;

      if (data && data.length > 0) {
        setNewAssignedTickets(data);
      }
    } catch (error) {
      console.error('Error checking new assigned tickets:', error);
    }
  };

  const fetchUsers = async () => {
    try {
      const { data, error } = await supabase.from('users').select('*');
      if (error) throw error;
      setUsers(data || []);
    } catch (error) {
      console.error('Error fetching users:', error);
    }
  };

  const handleChangeOrg = () => {
    localStorage.removeItem('selectedOrganization');
    navigate('/');
  };

  const handleTicketClick = (ticket: Ticket) => {
    setSelectedTicket(ticket);
    setIsCreateModalOpen(true);
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
            <div className="flex items-center space-x-4">
              <Brain className="w-8 h-8 text-white" />
              <div>
                <div className="text-2xl font-bold text-white">{selectedOrg?.name}</div>
                <div className="text-sm text-white/80">Help Desk Manager</div>
              </div>
            </div>
            <div className="flex items-center space-x-6">
              <NotificationBell notifications={newAssignedTickets} setNotifications={setNewAssignedTickets} />
              <div className="flex items-center space-x-4">
                <span className="text-white">{user?.email}</span>
                <button
                  onClick={handleChangeOrg}
                  className="p-2 text-white rounded-full hover:bg-white/10"
                  title="Change Organization"
                >
                  <Building2 className="w-6 h-6" />
                </button>
                <button
                  onClick={() => signOut()}
                  className="px-4 py-2 rounded text-white border border-white/30 hover:bg-white/10"
                >
                  Sign Out
                </button>
              </div>
            </div>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
          <div className="dashboard-card">
            <div className="text-2xl font-bold">{stats.totalTickets}</div>
            <div className="text-gray-500">Total Tickets</div>
          </div>
          <div className="dashboard-card">
            <div className="text-2xl font-bold">{stats.openTickets}</div>
            <div className="text-gray-500">Open Tickets</div>
          </div>
          <div className="dashboard-card">
            <div className="text-2xl font-bold">{stats.resolvedToday}</div>
            <div className="text-gray-500">Resolved Today</div>
          </div>
          <div className="dashboard-card">
            <div className="text-2xl font-bold">{stats.avgResponseTime}h</div>
            <div className="text-gray-500">Avg. Response Time</div>
          </div>
        </div>

        <div className="dashboard-card">
          <div className="flex justify-between items-center mb-6">
            <button 
              className="px-4 py-2 text-white rounded-md"
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
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="px-4 py-2 border rounded-md min-w-[150px]"
              >
                <option value="">All Status</option>
                <option value="open">Open</option>
                <option value="in_progress">In Progress</option>
                <option value="closed">Closed</option>
              </select>
            </div>
          </div>

          <div className="table-container">
            <table>
              <thead className="bg-gray-50">
                <tr>
                  <th>Ticket No</th>
                  <th>Client</th>
                  <th>Issue Type</th>
                  <th>Assigned To</th>
                  <th>Status</th>
                  <th>Created</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {tickets.map((ticket: Ticket) => (
                  <tr 
                    key={ticket.id} 
                    className="hover:bg-gray-50 cursor-pointer"
                    onClick={() => handleTicketClick(ticket)}
                  >
                    <td className="font-medium">{ticket.ticket_no}</td>
                    <td>{ticket.name_of_client}</td>
                    <td>{ticket.issue_type}</td>
                    <td>{ticket.assigned_to ? users.find(u => u.id === ticket.assigned_to)?.email || 'Unknown' : 'Unassigned'}</td>
                    <td>
                      <span
                        className="status-badge"
                        style={{
                          backgroundColor: selectedOrg.theme_accent_color + '20',
                          color: selectedOrg.theme_accent_color
                        }}
                      >
                        {ticket.status}
                      </span>
                    </td>
                    <td>{new Date(ticket.created_on).toLocaleDateString()}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </main>

      <CreateTicketModal
        isOpen={isCreateModalOpen}
        onClose={() => setIsCreateModalOpen(false)}
        organizationId={selectedOrg.id}
        onTicketCreated={fetchTickets}
        ticket={selectedTicket}
      />
    </div>
  );
}