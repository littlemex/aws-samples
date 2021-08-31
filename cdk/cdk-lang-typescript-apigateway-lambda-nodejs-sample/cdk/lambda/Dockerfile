FROM amazon/aws-lambda-nodejs:12
COPY index.ts package.json package-lock.json ${LAMBDA_TASK_ROOT}/ 
RUN npm install
CMD ["index.handler"]