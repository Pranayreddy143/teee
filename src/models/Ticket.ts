export class Ticket {
    id: string;
    title: string;
    description: string;
    status: TicketStatus;
    createdBy: string;
    createdAt: Date;
    updatedAt: Date;

    constructor(data: Partial<Ticket>) {
        this.id = data.id || crypto.randomUUID();
        this.title = data.title || '';
        this.description = data.description || '';
        this.status = data.status || TicketStatus.OPEN;
        this.createdBy = data.createdBy || '';
        this.createdAt = data.createdAt || new Date();
        this.updatedAt = data.updatedAt || new Date();
    }
}

export enum TicketStatus {
    OPEN = 'OPEN',
    IN_PROGRESS = 'IN_PROGRESS',
    CLOSED = 'CLOSED'
}
