import { Entity, Column, PrimaryGeneratedColumn, ManyToOne, CreateDateColumn } from 'typeorm';
import { User } from '../../users/entities/user.entity';

@Entity('tickets')
export class Ticket {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  ticket_no!: string;

  @Column()
  created_on!: Date;

  @Column()
  opened_by!: string;

  @Column()
  client_file_no!: string;

  @Column()
  mobile_no!: string;

  @Column()
  name_of_client!: string;

  @Column()
  issue_type!: string;

  @Column({ nullable: true })
  description: string | null = null;

  @Column({ nullable: true })
  resolution: string | null = null;

  @Column({ nullable: true })
  closed_on: Date | null = null;

  @Column({ nullable: true })
  closed_by: string | null = null;

  @Column({ default: 'open' })
  status: string = 'open';

  @Column('uuid', { nullable: true })
  assigned_to: string | null = null;

  @ManyToOne(() => User, user => user.assignedTickets)
  assignee: User | null = null;

  @Column('uuid')
  organization_id!: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;
}