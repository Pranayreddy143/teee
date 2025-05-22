import React, { useState, useEffect } from 'react';
import { Bell } from 'lucide-react';
import { supabase } from '../supabaseClient';
import { useAuth } from '../auth';
import { RealtimePostgresChangesPayload } from '@supabase/supabase-js';
import { useNavigate } from 'react-router-dom';
import { toast } from 'react-toastify';

interface NotificationBellProps {
  notifications: Array<any>;
  setNotifications: React.Dispatch<React.SetStateAction<Array<any>>>;
}

const NotificationBell: React.FC<NotificationBellProps> = ({ notifications, setNotifications }) => {
  const [isOpen, setIsOpen] = useState(false);
  const { user } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    const fetchNotifications = async () => {
      if (!user) return;
      
      try {
        const { data, error } = await supabase
          .rpc('get_user_notifications', {
            p_user_id: user.id
          });

        if (error) throw error;
        setNotifications(data || []);
      } catch (error) {
        console.error('Error fetching notifications:', error);
      }
    };

    fetchNotifications();
    
    // Set up real-time subscription
    const subscription = supabase
      .channel('ticket-notifications')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'tickets',
          filter: `assigned_to=eq.${user?.id}`
        },
        (_payload: RealtimePostgresChangesPayload<any>) => {
          fetchNotifications();
        }
      )
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, [user, setNotifications]);

  const toggleDropdown = (e: React.MouseEvent) => {
    e.stopPropagation();
    setIsOpen(!isOpen);
  };

  const handleNotificationClick = async (ticket: any) => {
    try {
      // Close the notification dropdown
      setIsOpen(false);
      
      // Mark the ticket as in progress if it's new
      if (ticket.status === 'open') {
        const { error } = await supabase
          .from('tickets')
          .update({ status: 'in_progress' })
          .eq('id', ticket.id);

        if (error) throw error;
      }

      // Navigate to the ticket in the create/edit modal
      const orgData = localStorage.getItem('selectedOrganization');
      if (orgData) {
        const org = JSON.parse(orgData);
        navigate(`/${org.slug}?ticket=${ticket.id}`);
      }
    } catch (error) {
      console.error('Error handling notification click:', error);
      toast.error('Failed to update ticket status');
    }
  };

  return (
    <div className="relative">
      <button
        onClick={toggleDropdown}
        className="p-2 text-white rounded-full hover:bg-white/10 relative"
        title="Notifications"
      >
        <Bell className="w-6 h-6" />
        {notifications.length > 0 && (
          <span className="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full h-5 w-5 flex items-center justify-center">
            {notifications.length}
          </span>
        )}
      </button>

      {isOpen && (
        <div className="absolute right-0 mt-2 w-80 bg-white shadow-lg rounded-lg z-50">
          <div className="p-4 border-b font-bold flex justify-between items-center">
            <span>Notifications</span>
            <span className="text-sm text-gray-500">{notifications.length} new</span>
          </div>
          <ul className="max-h-96 overflow-y-auto">
            {notifications.length > 0 ? (
              notifications.map((ticket) => (
                <li 
                  key={ticket.id} 
                  className="p-4 border-b last:border-none hover:bg-gray-50 cursor-pointer transition-colors"
                  onClick={() => handleNotificationClick(ticket)}
                >
                  <div className="font-medium">Ticket #{ticket.ticket_no}</div>
                  <div className="text-sm text-gray-600 mt-1">{ticket.name_of_client}</div>
                  <div className="text-xs text-gray-500 mt-1">
                    {new Date(ticket.created_on).toLocaleDateString()}
                  </div>
                </li>
              ))
            ) : (
              <li className="p-4 text-center text-gray-500">No new notifications</li>
            )}
          </ul>
        </div>
      )}
    </div>
  );
};

export default NotificationBell;