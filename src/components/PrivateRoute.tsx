import { ReactNode } from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '../auth';

interface PrivateRouteProps {
  children: ReactNode | ((props: any) => ReactNode);
}

export function PrivateRoute({ children }: PrivateRouteProps) {
  const { user, loading } = useAuth();

  // If still loading auth state, show nothing
  if (loading) {
    return null;
  }

  // If not authenticated, redirect to login
  if (!user) {
    return <Navigate to="/login" replace />;
  }

  // If children is a function, call it with props
  if (typeof children === 'function') {
    return <>{children({})}</>;
  }

  // Otherwise render children directly
  return <>{children}</>;
}
