import { Component, OnInit } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { TicketService } from '../ticket.service';
import { UserService } from '../../users/user.service';

@Component({
  selector: 'app-ticket-detail',
  templateUrl: './ticket-detail.component.html',
  styleUrls: ['./ticket-detail.component.css']
})
export class TicketDetailComponent implements OnInit {
  ticket: any;
  selectedUserId: number;
  users: any[] = [];

  constructor(
    private ticketService: TicketService,
    private userService: UserService,
    private route: ActivatedRoute
  ) {}

  ngOnInit() {
    const ticketId = this.route.snapshot.paramMap.get('id');
    if (ticketId) {
      this.ticketService.getTicket(ticketId).subscribe(
        (ticket) => {
          this.ticket = ticket;
        },
        (error) => {
          console.error('Error fetching ticket:', error);
        }
      );
    }
    this.loadUsers();
  }

  loadUsers() {
    this.userService.getUsers().subscribe(
      (users) => {
        this.users = users;
      }
    );
  }

  assignTicket() {
    if (this.selectedUserId && this.ticket.id) {
      this.ticketService.assignTicket(this.ticket.id, this.selectedUserId).subscribe(
        (updatedTicket) => {
          this.ticket = updatedTicket;
          // Show success message
          alert('Ticket assigned successfully');
        },
        (error) => {
          console.error('Error assigning ticket:', error);
          alert('Failed to assign ticket');
        }
      );
    }
  }
}