import { Controller, Post, Body, Param, ParseIntPipe } from '@nestjs/common';
import { TicketsService } from './tickets.service';

@Controller('tickets')
export class TicketsController {
  constructor(private readonly ticketsService: TicketsService) {}

  @Post(':id/assign')
  async assignTicket(
    @Param('id', ParseIntPipe) id: number,
    @Body('userId') userId: number,
  ) {
    return await this.ticketsService.assignTicket(id, userId);
  }
}