import { Entity, Column, PrimaryGeneratedColumn, OneToMany } from 'typeorm';
import { Ticket } from '../../tickets/entities/ticket.entity';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ unique: true })
  email!: string;

  @Column()
  role!: string;

  @Column({ name: 'created_at' })
  createdAt!: Date;

  @OneToMany(() => Ticket, ticket => ticket.assignee)
  assignedTickets: Ticket[] = [];
}