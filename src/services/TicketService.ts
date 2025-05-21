import { Ticket } from '../models/Ticket';

export class TicketService {
    private tickets: Ticket[] = [];

    createTicket(ticketData: Partial<Ticket>): Ticket {
        const ticket = new Ticket(ticketData);
        this.validateTicket(ticket);
        this.tickets.push(ticket);
        return ticket;
    }

    private validateTicket(ticket: Ticket): void {
        if (!ticket.title) {
            throw new Error('Ticket title is required');
        }
        if (!ticket.description) {
            throw new Error('Ticket description is required');
        }
        if (!ticket.createdBy) {
            throw new Error('Ticket creator is required');
        }
    }

    getTicketById(id: string): Ticket | undefined {
        return this.tickets.find(ticket => ticket.id === id);
    }

    getAllTickets(): Ticket[] {
        return this.tickets;
    }
}
