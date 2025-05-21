import React, { useState, useEffect } from 'react';
import { X, AlertCircle, Copy, CheckCircle2 } from 'lucide-react';
import { supabase } from '../supabaseClient';
import { toast } from 'react-toastify';
import { useAuth } from '../auth';

interface FileAttachment {
  name: string;
  size: number;
  type: string;
  url: string;
}

interface CreateTicketModalProps {
  isOpen: boolean;
  onClose: () => void;
  organizationId: string;
  onTicketCreated: () => void;
  ticket?: any;
}

export default function CreateTicketModal({ isOpen, onClose, organizationId, onTicketCreated, ticket }: CreateTicketModalProps) {
  const [formData, setFormData] = useState({
    ticketNo: ticket?.ticket_no || '',
    createdOn: ticket?.created_on || new Date().toISOString().split('T')[0],
    openedBy: ticket?.opened_by || '',
    clientFileNo: ticket?.client_file_no || '',
    mobileNo: ticket?.mobile_no || '',
    nameOfClient: ticket?.name_of_client || '',
    issueType: ticket?.issue_type || '',
    description: ticket?.description || '',
    resolution: ticket?.resolution || '',
    closedOn: ticket?.closed_on || '',
    closedBy: ticket?.closed_by || '',
    status: ticket?.status || 'open'
  });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [copied, setCopied] = useState(false);
  const [selectedUser, setSelectedUser] = useState<string | null>(ticket?.assigned_to || null);
  const [selectedClosedBy, setSelectedClosedBy] = useState<string | null>(ticket?.closed_by || null);
  const [users, setUsers] = useState<{ id: string, email: string }[]>([]);
  const [isLoadingUsers, setIsLoadingUsers] = useState(false);
  const [attachments, setAttachments] = useState<FileAttachment[]>([]);
  const [isUploading, setIsUploading] = useState(false);

  const issueTypes = [
    'Declaration',
    'Estimation',
    'Payment',
    'Filing Update',
    'Refund Update',
    'Notice U/s 148',
    'Notice U/s 133(6)',
    'Other Notices',
    'GST Filing',
    'Referral Bonus',
    'GST Registration',
    'Filing Copies',
    'Computation Copies',
    'Others'
  ];

  const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB
  const ALLOWED_FILE_TYPES = [
    'image/jpeg',
    'image/png',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ];

  // Get current user
  const { user } = useAuth();

  // Reset form when modal opens/closes or ticket changes
  useEffect(() => {
    if (ticket) {
      setFormData({
        ticketNo: ticket.ticket_no || '',
        createdOn: ticket.created_on || new Date().toISOString().split('T')[0],
        openedBy: ticket.opened_by || user?.email || '',
        clientFileNo: ticket.client_file_no || '',
        mobileNo: ticket.mobile_no || '',
        nameOfClient: ticket.name_of_client || '',
        issueType: ticket.issue_type || '',
        description: ticket.description || '',
        resolution: ticket.resolution || '',
        closedOn: ticket.closed_on || '',
        closedBy: ticket.closed_by || '',
        status: ticket.status || 'open'
      });
      setSelectedUser(ticket.assigned_to || null);
      setSelectedClosedBy(ticket.closed_by || null);
    } else {
      setFormData({
        ticketNo: '',
        createdOn: new Date().toISOString().split('T')[0],
        openedBy: user?.email || '',
        clientFileNo: '',
        mobileNo: '',
        nameOfClient: '',
        issueType: '',
        description: '',
        resolution: '',
        closedOn: '',
        closedBy: '',
        status: 'open'
      });
      setSelectedUser(null);
      setSelectedClosedBy(null);
    }
  }, [ticket, isOpen, user]);

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    setIsLoadingUsers(true);
    try {
      const { data, error } = await supabase
        .from('users')
        .select('id, email');

      if (error) throw error;
      setUsers(data || []);
    } catch (error) {
      console.error('Error fetching users:', error);
      toast.error('Failed to load users');
    } finally {
      setIsLoadingUsers(false);
    }
  };

  const handleCopyTicketNo = () => {
    if (formData.ticketNo) {
      navigator.clipboard.writeText(formData.ticketNo);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000); // Reset after 2 seconds
      toast.success('Ticket number copied to clipboard!');
    }
  };

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files || files.length === 0) return;

    setIsUploading(true);
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('User not authenticated');

      for (const file of files) {
        // File size validation
        if (file.size > MAX_FILE_SIZE) {
          toast.error(`File ${file.name} exceeds 10MB limit`);
          continue;
        }

        // File type validation
        if (!ALLOWED_FILE_TYPES.includes(file.type)) {
          toast.error(`File type not supported for ${file.name}`);
          continue;
        }

        const fileExt = file.name.split('.').pop();
        const fileName = `${user.id}/${Date.now()}-${crypto.randomUUID()}.${fileExt}`;

        const { error: uploadError } = await supabase.storage
          .from('ticket-attachments')
          .upload(fileName, file, {
            cacheControl: '3600',
            upsert: false,
            contentType: file.type
          });

        if (uploadError) {
          console.error('Upload error:', uploadError);
          toast.error(`Failed to upload ${file.name}`);
          continue;
        }

        const { data: { publicUrl } } = supabase.storage
          .from('ticket-attachments')
          .getPublicUrl(fileName);

        setAttachments(prev => [...prev, {
          name: file.name,
          size: file.size,
          type: file.type,
          url: publicUrl
        }]);
        
        toast.success(`Successfully uploaded ${file.name}`);
      }
    } catch (error: any) {
      console.error('Error uploading file:', error);
      toast.error(error.message || 'Failed to upload files');
    } finally {
      setIsUploading(false);
      // Reset file input
      e.target.value = '';
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);

    try {
      const { data: userData } = await supabase.auth.getUser();
      if (!userData.user) throw new Error('User not authenticated');

      const ticketData = {
        client_file_no: formData.clientFileNo,
        mobile_no: formData.mobileNo,
        name_of_client: formData.nameOfClient,
        issue_type: formData.issueType,
        description: formData.description,
        resolution: formData.resolution,
        status: formData.status,
        closed_on: formData.status === 'closed' ? formData.closedOn : null,
        closed_by: selectedClosedBy, // Use selectedClosedBy instead of formData.closedBy
        assigned_to: selectedUser,
        organization_id: organizationId
      };

      if (ticket) {
        // Update existing ticket
        const { error } = await supabase
          .from('tickets')
          .update(ticketData)
          .eq('id', ticket.id);

        if (error) throw error;
        
        // Send notification for assignment change if needed
        if (selectedUser && selectedUser !== ticket.assigned_to) {
          await supabase.rpc('notify_ticket_assignment', {
            p_ticket_id: ticket.id,
            p_assigned_to: selectedUser
          });
        }
        
        toast.success('Ticket updated successfully');
      } else {
        // Create new ticket
        const { error: createError } = await supabase.rpc('create_ticket', {
          p_opened_by: userData.user.email,
          p_client_file_no: formData.clientFileNo,
          p_mobile_no: formData.mobileNo,
          p_name_of_client: formData.nameOfClient,
          p_issue_type: formData.issueType,
          p_description: formData.description,
          p_organization_id: organizationId,
          p_assigned_to: selectedUser
        });

        if (createError) throw createError;
        toast.success('Ticket created successfully');
      }

      onTicketCreated();
      onClose();
    } catch (error: any) {
      console.error('Error saving ticket:', error);
      toast.error(error.message || 'Failed to save ticket');
    } finally {
      setIsSubmitting(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal-container">
      <div className="modal-content">
        <div className="bg-gradient-to-r from-blue-600 to-blue-800 rounded-t-lg p-6">
          <div className="flex items-center justify-between">
            <h2 className="text-2xl font-bold text-white flex items-center">
              <AlertCircle className="w-6 h-6 mr-2" />
              {ticket ? 'Edit Ticket' : 'New Ticket'}
            </h2>
            <button
              onClick={onClose}
              className="text-white hover:text-gray-200 transition-colors"
            >
              <X className="w-6 h-6" />
            </button>
          </div>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6 overflow-y-auto">
          <div className="grid grid-cols-3 gap-6">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Ticket No #
              </label>
              <div className="relative">
                <input
                  type="text"
                  value={formData.ticketNo}
                  readOnly
                  className="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50 pr-10 font-mono"
                  placeholder="Auto-generated"
                />
                {formData.ticketNo && (
                  <button
                    type="button"
                    onClick={handleCopyTicketNo}
                    className="absolute right-2 top-1/2 transform -translate-y-1/2 text-gray-500 hover:text-blue-600 focus:outline-none"
                    title="Copy ticket number"
                  >
                    {copied ? (
                      <CheckCircle2 className="w-5 h-5 text-green-500" />
                    ) : (
                      <Copy className="w-5 h-5" />
                    )}
                  </button>
                )}
              </div>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Created On
              </label>
              <input
                type="date"
                value={formData.createdOn}
                onChange={(e) => setFormData({ ...formData, createdOn: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 rounded-md"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Opened By
              </label>
              <input
                type="text"
                value={formData.openedBy}
                disabled
                className="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50"
                placeholder="Auto-filled with your email"
              />
            </div>
          </div>

          <div className="grid grid-cols-3 gap-6">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Client File No
              </label>
              <input
                type="text"
                required
                value={formData.clientFileNo}
                onChange={(e) => setFormData({ ...formData, clientFileNo: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500"
                placeholder="Enter file number"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Mobile No
              </label>
              <input
                type="text"
                required
                value={formData.mobileNo}
                onChange={(e) => setFormData({ ...formData, mobileNo: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500"
                placeholder="Enter mobile number"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Name of Client
              </label>
              <input
                type="text"
                required
                value={formData.nameOfClient}
                onChange={(e) => setFormData({ ...formData, nameOfClient: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500"
                placeholder="Enter client name"
              />
            </div>
          </div>

          <div className="grid grid-cols-3 gap-6">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Status
              </label>
              <select
                value={formData.status}
                onChange={(e) => setFormData({ ...formData, status: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 bg-white"
              >
                <option value="open">Open</option>
                <option value="in_progress">In Progress</option>
                <option value="closed">Closed</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Issue Type
              </label>
              <select
                required
                value={formData.issueType}
                onChange={(e) => setFormData({ ...formData, issueType: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 bg-white"
              >
                <option value="">Select Issue Type</option>
                {issueTypes.map((type) => (
                  <option key={type} value={type}>
                    {type}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Description of Issue
            </label>
            <textarea
              required
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 resize-none"
              rows={4}
              placeholder="Describe the issue in detail..."
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Resolution of Issue
            </label>
            <textarea
              value={formData.resolution}
              onChange={(e) => setFormData({ ...formData, resolution: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 resize-none"
              rows={4}
              placeholder="Enter resolution details..."
            />
          </div>

          <div className="grid grid-cols-3 gap-6">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Closed On
              </label>
              <input
                type="date"
                value={formData.closedOn}
                onChange={(e) => setFormData({ ...formData, closedOn: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 rounded-md"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Closed By
              </label>
              <select
                value={selectedClosedBy || ''}
                onChange={(e) => setSelectedClosedBy(e.target.value || null)}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 bg-white"
                disabled={isLoadingUsers}
              >
                <option value="">Select user</option>
                {users.map((user) => (
                  <option key={user.id} value={user.id}>
                    {user.email}
                  </option>
                ))}
              </select>
              {isLoadingUsers && (
                <div className="mt-2 text-sm text-gray-500">Loading users...</div>
              )}
            </div>
          </div>

          <div className="grid grid-cols-3 gap-6">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Assign To
              </label>
              <select
                value={selectedUser || ''}
                onChange={(e) => setSelectedUser(e.target.value || null)}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 bg-white"
                disabled={isLoadingUsers}
              >
                <option value="">Unassigned</option>
                {users.map((user) => (
                  <option key={user.id} value={user.id}>
                    {user.email}
                  </option>
                ))}
              </select>
              {isLoadingUsers && (
                <div className="mt-2 text-sm text-gray-500">Loading users...</div>
              )}
            </div>
          </div>

          <div className="space-y-4">
            <label className="block text-sm font-medium text-gray-700">
              Attachments
            </label>
            <div className="flex items-center space-x-4">
              <input
                type="file"
                multiple
                onChange={handleFileUpload}
                className="hidden"
                id="file-upload"
                disabled={isUploading}
              />
              <label
                htmlFor="file-upload"
                className="px-4 py-2 bg-gray-100 rounded cursor-pointer hover:bg-gray-200 transition-colors"
              >
                {isUploading ? 'Uploading...' : 'Add Files'}
              </label>
            </div>
            {attachments.length > 0 && (
              <div className="space-y-2">
                {attachments.map((file, index) => (
                  <div key={index} className="flex items-center justify-between p-2 bg-gray-50 rounded">
                    <span className="text-sm text-gray-600">{file.name}</span>
                    <button
                      type="button"
                      onClick={() => setAttachments(prev => prev.filter((_, i) => i !== index))}
                      className="text-red-500 hover:text-red-700"
                    >
                      <X size={16} />
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="flex justify-end space-x-3 pt-4 border-t sticky bottom-0 bg-white">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded-md hover:bg-gray-200 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700 disabled:opacity-50 transition-colors flex items-center"
            >
              {isSubmitting ? (
                <>
                  <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  Saving...
                </>
              ) : ticket ? 'Update Ticket' : 'Create Ticket'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}