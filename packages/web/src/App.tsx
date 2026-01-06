import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { useState } from 'react';

// Placeholder components - to be implemented
function Dashboard() {
  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-4xl font-bold mb-8">Heating Design Pro</h1>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white p-6 rounded-lg shadow-md">
          <h2 className="text-xl font-semibold mb-4">Projects</h2>
          <p className="text-gray-600">Manage your heating design projects</p>
        </div>
        <div className="bg-white p-6 rounded-lg shadow-md">
          <h2 className="text-xl font-semibold mb-4">Calculations</h2>
          <p className="text-gray-600">Heat loss and radiator sizing</p>
        </div>
        <div className="bg-white p-6 rounded-lg shadow-md">
          <h2 className="text-xl font-semibold mb-4">Reports</h2>
          <p className="text-gray-600">Generate professional PDFs</p>
        </div>
      </div>
    </div>
  );
}

function Projects() {
  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-6">Projects</h1>
      <p>Projects list - to be implemented</p>
    </div>
  );
}

function Calculations() {
  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-6">Heat Loss Calculations</h1>
      <p>Calculation interface - to be implemented</p>
    </div>
  );
}

function App() {
  return (
    <BrowserRouter>
      <div className="min-h-screen bg-gray-50">
        <nav className="bg-sky-700 text-white shadow-lg">
          <div className="container mx-auto px-4">
            <div className="flex items-center justify-between h-16">
              <div className="flex items-center">
                <span className="text-xl font-bold">Heating Design Pro</span>
              </div>
              <div className="flex space-x-4">
                <a href="/" className="hover:bg-sky-600 px-3 py-2 rounded">
                  Dashboard
                </a>
                <a href="/projects" className="hover:bg-sky-600 px-3 py-2 rounded">
                  Projects
                </a>
                <a href="/calculations" className="hover:bg-sky-600 px-3 py-2 rounded">
                  Calculations
                </a>
              </div>
            </div>
          </div>
        </nav>

        <main>
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/projects" element={<Projects />} />
            <Route path="/calculations" element={<Calculations />} />
          </Routes>
        </main>

        <footer className="bg-gray-800 text-white mt-12">
          <div className="container mx-auto px-4 py-6">
            <p className="text-center text-sm">
              © 2024 Heating Design Pro - Professional Heating System Design
            </p>
          </div>
        </footer>
      </div>
    </BrowserRouter>
  );
}

export default App;
