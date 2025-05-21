import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class TicketService {
  private apiUrl = 'http://localhost:3000/api';

  constructor(private http: HttpClient) {}

  getTickets(): Observable<any> {
    return this.http.get(`${this.apiUrl}/tickets`);
  }

  getTicketById(ticketId: number): Observable<any> {
    return this.http.get(`${this.apiUrl}/tickets/${ticketId}`);
  }

  createTicket(ticketData: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/tickets`, ticketData);
  }

  updateTicket(ticketId: number, ticketData: any): Observable<any> {
    return this.http.put(`${this.apiUrl}/tickets/${ticketId}`, ticketData);
  }

  deleteTicket(ticketId: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/tickets/${ticketId}`);
  }

  assignTicket(ticketId: number, userId: number): Observable<any> {
    return this.http.post(`${this.apiUrl}/tickets/${ticketId}/assign`, { userId });
  }
}