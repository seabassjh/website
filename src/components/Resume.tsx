import React, { FC } from 'react';


const Resume: FC = () => {
  return (
    <div style={{
      backgroundColor: "#CCCCCC11",
      borderWidth: "3px",
      borderStyle: "solid",
      borderColor: "#CCCCCC",
      borderRadius: "10px",
      overflow: "hidden",
      display: "flex",
      justifyContent: "center",
      alignItems: "center",
      flexDirection: "column",
    }}>
    <iframe src="https://seabassjh.github.io/latex-resume/resume-embed.html" title="resumeFrame" style= {{border: "0", width: "100vw", maxWidth: "8.5in", height: "100vh", maxHeight: "11in"}}></iframe>
    </div>
  );
};

export default Resume;