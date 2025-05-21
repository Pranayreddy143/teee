import { Routes, Route, Navigate } from 'react-router-dom';
import { ToastContainer } from 'react-toastify';
import 'react-toastify/dist/ReactToastify.css';
import { useAuth } from './auth';
import { Login } from './Login';
import FreeTaxFilerDashboard from './components/organizations/FreeTaxFilerDashboard';
import OnlineTaxFilerDashboard from './components/organizations/OnlineTaxFilerDashboard';
import USeTaxFilerDashboard from './components/organizations/USeTaxFilerDashboard';
import AIUSTaxDashboard from './components/organizations/AIUSTaxDashboard';
import TestComponents from './components/TestComponents';
import { PrivateRoute } from './components/PrivateRoute.tsx';

function App() {
  const { user } = useAuth();

  // Special test route that bypasses authentication
  if (window.location.pathname === '/test') {
    return (
      <>
        <ToastContainer />
        <TestComponents />
      </>
    );
  }

  // If user is not authenticated, show login or redirect to login page
  if (!user) {
    if (window.location.pathname === '/login') {
      return (
        <>
          <ToastContainer />
          <Login />
        </>
      );
    }
    return <Navigate to="/login" replace />;
  }

  return (
    <>
      <ToastContainer />
      <Routes>
        <Route
          path="/"
          element={
            <PrivateRoute>
              {() => {
                const selectedOrg = localStorage.getItem('selectedOrganization');
                if (!selectedOrg) {
                  return null; // or a component to select organization
                }
                const org = JSON.parse(selectedOrg);
                return <Navigate to={`/org/${org.slug}`} replace />;
              }}
            </PrivateRoute>
          }
        />
        <Route 
          path="/org/free-tax-filer" 
          element={<PrivateRoute><FreeTaxFilerDashboard /></PrivateRoute>} 
        />
        <Route 
          path="/org/online-tax-filer" 
          element={<PrivateRoute><OnlineTaxFilerDashboard /></PrivateRoute>} 
        />
        <Route 
          path="/org/us-tax-filer" 
          element={<PrivateRoute><USeTaxFilerDashboard /></PrivateRoute>} 
        />
        <Route 
          path="/org/aius-tax" 
          element={<PrivateRoute><AIUSTaxDashboard /></PrivateRoute>} 
        />
        <Route path="/login" element={<Login />} />
        {/* Catch-all route for unknown paths */}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </>
  );
}

export default App;