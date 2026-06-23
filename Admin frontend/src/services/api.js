const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:8000';

export const fetchComplaints = async () => {
  try {
    const response = await fetch(`${API_BASE_URL}/complaints`);
    if (!response.ok) {
      let errData = {};
      try { errData = await response.json(); } catch(e){}
      throw new Error(errData.detail || errData.error || 'Failed to fetch complaints');
    }
    return await response.json();
  } catch (error) {
    console.error("Error fetching complaints:", error);
    throw error;
  }
};

export const analyzeQuery = async (query) => {
  try {
    const response = await fetch(`${API_BASE_URL}/gemini-analyze`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ query })
    });
    
    if (!response.ok) {
      let errData = {};
      try { errData = await response.json(); } catch(e){}
      throw new Error(errData.detail || errData.error || 'Failed to analyze query');
    }
    return await response.json();
  } catch (error) {
    console.error("Error analyzing query:", error);
    throw error;
  }
};

export const confirmComplaint = async (id) => {
  const response = await fetch(`${API_BASE_URL}/complaints/${id}/confirm`, { method: 'POST' });
  if (!response.ok) {
    let errData = {};
    try { errData = await response.json(); } catch(e){}
    throw new Error(errData.detail || errData.error || 'Failed to confirm complaint');
  }
  return response.json();
};

export const markDuplicate = async (id) => {
  const response = await fetch(`${API_BASE_URL}/complaints/${id}/duplicate`, { method: 'POST' });
  if (!response.ok) {
    let errData = {};
    try { errData = await response.json(); } catch(e){}
    throw new Error(errData.detail || errData.error || 'Failed to mark duplicate');
  }
  return response.json();
};

export const updateComplaintStatus = async (id, status, resolvedImageFile) => {
  const formData = new FormData();
  formData.append('complaint_id', id);
  formData.append('status', status);
  if (resolvedImageFile) formData.append('resolved_image', resolvedImageFile);

  const response = await fetch(`${API_BASE_URL}/update-complaint`, {
    method: 'PUT',
    body: formData,
  });
  if (!response.ok) {
    let errData = {};
    try { errData = await response.json(); } catch(e){}
    throw new Error(errData.detail || errData.error || 'Failed to update status');
  }
  return response.json();
};


