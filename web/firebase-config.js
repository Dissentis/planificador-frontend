import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.7.0/firebase-app.js';
import { getAuth } from 'https://www.gstatic.com/firebasejs/10.7.0/firebase-auth.js';

const firebaseConfig = {
  apiKey: "AIzaSyAHZzs4xWCraSEgC7PU7dNQZ7P_bf9vVNo",
  authDomain: "planificador-docente-a32f9.firebaseapp.com",
  projectId: "planificador-docente-a32f9",
  storageBucket: "planificador-docente-a32f9.firebasestorage.app",
  messagingSenderId: "23073331643",
  appId: "1:23073331643:web:8cd2bc23ab61a609200c9e",
  measurementId: "G-ZDX0PT5TRC"
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);