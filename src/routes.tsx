import { createBrowserRouter } from 'react-router-dom';
import Login from './Login';
import Dashboard from './components/Dashboard';
import AIUSTaxDashboard from './components/organizations/AIUSTaxDashboard';
import FreeTaxFilerDashboard from './components/organizations/FreeTaxFilerDashboard';
import OnlineTaxFilerDashboard from './components/organizations/OnlineTaxFilerDashboard';
import USeTaxFilerDashboard from './components/organizations/USeTaxFilerDashboard';
import { PrivateRoute } from './components/PrivateRoute';

export const router = createBrowserRouter([
  {
    path: '/login',
    element: <Login />,
  },
  {
    path: '/',
    element: <PrivateRoute><Dashboard /></PrivateRoute>,
  },
  {
    path: '/org/aius-tax',
    element: <PrivateRoute><AIUSTaxDashboard /></PrivateRoute>,
  },
  {
    path: '/org/free-tax-filer',
    element: <PrivateRoute><FreeTaxFilerDashboard /></PrivateRoute>,
  },
  {
    path: '/org/online-tax-filer',
    element: <PrivateRoute><OnlineTaxFilerDashboard /></PrivateRoute>,
  },
  {
    path: '/org/us-tax-filer',
    element: <PrivateRoute><USeTaxFilerDashboard /></PrivateRoute>,
  },
]);
