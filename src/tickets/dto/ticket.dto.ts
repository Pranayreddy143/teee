export class TicketDto {
  id: number;
  title: string;
  description: string;
  status: string;
  createdAt: Date;
  updatedAt: Date;
  assigneeId?: number;
  assignee?: {
    id: number;
    username: string;
    email: string;
  };
}